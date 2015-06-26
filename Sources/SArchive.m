/*
 *  SArchive.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SArchive.h>
#import <SArchiveKit/SArchiveFile.h>
#import <SArchiveKit/SArchiveDocument.h>

#include <pwd.h>
#include <grp.h>
#include <unistd.h>
#include <sys/time.h>
#include <libkern/OSAtomic.h>

#import "SArchiveXar.h"

#pragma mark Options
/* setting owner/group behavior */
NSString * const SArchiveOptionOwnershipBehaviourKey = @XAR_OPT_OWNERSHIP;
/* set owner/group based on names */
NSString * const SArchiveOptionOwnershipSymbolic = @XAR_OPT_VAL_SYMBOLIC;
/* set owner/group based on uid/gid */
NSString * const SArchiveOptionOwnershipNumeric = @XAR_OPT_VAL_NUMERIC;

/* Preserve setuid/getuid */
NSString * const SArchiveOptionSaveSUID = @XAR_OPT_SAVESUID;

NSString * const SArchiveOptionValueTrue = @XAR_OPT_VAL_TRUE;
NSString * const SArchiveOptionValueFalse = @XAR_OPT_VAL_FALSE;

/* set the toc checksum algorithm */
NSString * const SArchiveOptionTocCheckSumKey = @XAR_OPT_TOCCKSUM;
/* set the file checksum algorithm */
NSString * const SArchiveOptionFileCheckSumKey = @XAR_OPT_FILECKSUM;

NSString * const SArchiveOptionCheckSumNone = @XAR_OPT_VAL_NONE;
NSString * const SArchiveOptionCheckSumSHA1 = @XAR_OPT_VAL_SHA1;
NSString * const SArchiveOptionCheckSumSHA256 = @XAR_OPT_VAL_SHA256;
NSString * const SArchiveOptionCheckSumSHA512 = @XAR_OPT_VAL_SHA512;
NSString * const SArchiveOptionCheckSumMD5 = @XAR_OPT_VAL_MD5;

/* set the file compression type */
NSString * const SArchiveOptionCompressionKey = @XAR_OPT_COMPRESSION;

NSString * const SArchiveOptionCompressionGZip = @XAR_OPT_VAL_GZIP;
NSString * const SArchiveOptionCompressionBZip = @XAR_OPT_VAL_BZIP;
NSString * const SArchiveOptionCompressionLZMA = @XAR_OPT_VAL_LZMA;

/* include - exclude */
NSString * const SArchiveOptionIncludedProperty = @XAR_OPT_PROPINCLUDE;
NSString * const SArchiveOptionExcludedProperty = @XAR_OPT_PROPEXCLUDE;

/* Read io buffer size */
NSString * const SArchiveOptionReadBufferSize = @XAR_OPT_RSIZE;

/* Coalesce identical heap blocks */
NSString * const SArchiveOptionCoalesce = @XAR_OPT_COALESCE;
/* Hardlink identical files */
NSString * const SArchiveOptionLinkSame = @XAR_OPT_LINKSAME;

static
int32_t sa_xar_err_handler(int32_t severit, int32_t err, xar_errctx_t ctx, void *usrctx);

#pragma mark -
@implementation SArchive {
@private
  xar_t sa_arch;
  SArchiveFile *_rootFile;

  NSMapTable *_files;
  NSMutableArray *_signatures;
  NSMutableDictionary *_documents;

  /* extract context */
  id<SArchiveHandler> sa_delegate;

  bool _ok;
  volatile bool _cancel;
  volatile int32_t _extracting; /* atomic lock */
}

- (instancetype)initWithURL:(NSURL *)anURL {
  return [self initWithURL:anURL writable:NO];
}

- (instancetype)initWithURL:(NSURL *)anURL writable:(BOOL)flag {
  if (![anURL isFileURL]) {
    [self release];
    SPXThrowException(NSInvalidArgumentException, @"Unsupported URL scheme");
  }
  if (self = [super init]) {
    // Note: -[NSURL fileSystemRepresentation] is 10.9 only
    sa_arch = (void *)xar_open(SArchiveGetPath(anURL, false), flag ? WRITE : READ);
    if (!sa_arch) {
      [self release];
      self = nil;
    } else {
      _URL = [anURL retain];
      xar_register_errhandler(sa_arch, sa_xar_err_handler, self);
      _files = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
    }
  }
  return self;
}

- (void)dealloc {
  if (sa_arch) {
    [self close];
  }
  [_URL release];
  [super dealloc];
}

#pragma mark -
- (SArchiveFile *)sa_findFile:(xar_file_t)file {
  return file ? NSMapGet(_files, file) : nil;
}

- (SArchiveFile *)sa_addFile:(xar_file_t)file name:(NSString *)name parent:(SArchiveFile *)parent {
  SArchiveFile *f = nil;
  if (file) {
    f = [[SArchiveFile alloc] initWithArchive:sa_arch file:file];
    if (f) {
      f.name = name;
      NSMapInsert(_files, file, f);
      if (parent)
        [parent addFile:f];
      else
        [_rootFile addFile:f];
    }
  }
  return [f autorelease];
}

- (void)loadTOC {
  if (!_rootFile) {
    _rootFile = [[SArchiveFile alloc] initWithArchive:sa_arch file:NULL];

    xar_file_t file = NULL;
    xar_iter_t files = xar_iter_new();
    file = xar_file_first(sa_arch, files);
    while (file) {
      SArchiveFile *f = [self sa_findFile:file];
      if (!f) {
        SArchiveFile *p = [self sa_findFile:xar_file_get_parent(file)];
        f = [self sa_addFile:file name:nil parent:p];
      }
      file = xar_file_next(files);
    }
    xar_iter_free(files);
  } 
}

- (void)loadSignatures {
  if (!_signatures) {
    _signatures = [[NSMutableArray alloc] init];
    xar_signature_t sign = xar_signature_first(sa_arch);
    while (sign) {
      SArchiveSignature *asign = [[SArchiveSignature alloc] initWithSignature:sign];
      [_signatures addObject:asign];
      [asign release];
      sign = xar_signature_next(sign);
    }
  }
}

- (void)close {
  if (sa_arch) {
    xar_close(sa_arch);
    sa_arch = NULL;
    if (_files) {
      NSFreeMapTable(_files);
      _files = NULL;
    }
    [_rootFile release];
    _rootFile = nil;
    
    [_documents release];
    _documents = nil;
    
    [_signatures release];
    _signatures = nil;
  }
}

- (uint64_t)size {
  [self loadTOC];
  uint64_t size = 0;
  SArchiveFile *file;
  NSMapEnumerator files = NSEnumerateMapTable(_files);
  while (NSNextMapEnumeratorPair(&files, NULL, (void **)&file)) {
    size += file.size;
  }
  NSEndMapTableEnumeration(&files);
  return size;
}

- (NSArray *)rootFiles {
  [self loadTOC];
  return _rootFile.files;
}

- (NSUInteger)fileCount {
  [self loadTOC];
  return NSCountMapTable(_files);
}

- (NSEnumerator *)fileEnumerator {
  [self loadTOC];
  return [_rootFile enumerator];
}

- (SArchiveFile *)fileWithName:(NSString *)name {
  [self loadTOC];
  return [_rootFile fileWithName:name];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
  [self loadTOC];
  return [_rootFile countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Options
- (NSString *)valueForOption:(NSString *)key {
  const char *opt = xar_opt_get(sa_arch, [key UTF8String]);
  if (opt)
    return [NSString stringWithUTF8String:opt];
  return nil;
}

- (void)setValue:(NSString *)opt forOption:(NSString *)key {
  xar_opt_set(sa_arch, [key UTF8String], [opt UTF8String]);
}

- (BOOL)boolValueForOption:(NSString *)key {
  const char *opt = xar_opt_get(sa_arch, [key UTF8String]);
  if (opt) return 0 == strcmp(opt, XAR_OPT_VAL_TRUE);
  return NO;
}
- (void)setBoolValue:(BOOL)value forOption:(NSString *)key {
  xar_opt_set(sa_arch, [key UTF8String], value ? XAR_OPT_VAL_TRUE : XAR_OPT_VAL_FALSE);
}

- (SArchiveFile *)addFileAtURL:(NSURL *)url {
  xar_file_t file = xar_add(sa_arch, SArchiveGetPath(url, true));
  return [self sa_addFile:file name:nil parent:file ? [self sa_findFile:xar_file_get_parent(file)] : NULL];
}

- (SArchiveFile *)addFileAtURL:(NSURL *)url name:(NSString *)name parent:(SArchiveFile *)parent {
  xar_file_t file = xar_add_frompath(sa_arch, [parent file], [name UTF8String], SArchiveGetPath(url, true));
  return [self sa_addFile:file name:name parent:parent];
}

- (SArchiveFile *)addFileWithName:(NSString *)name content:(NSData *)data parent:(SArchiveFile *)parent {
  xar_file_t file = xar_add_frombuffer(sa_arch, [parent file], [name UTF8String], [data bytes], [data length]);
  SArchiveFile *f = [self sa_addFile:file name:name parent:parent];
  if (f)
    [f setPosixPermissions:0644];
  return f;
}

- (SArchiveFile *)addFolderWithName:(NSString *)name properties:(NSDictionary *)props parent:(SArchiveFile *)parent {
  struct stat info;
  bzero(&info, sizeof(info));
  NSNumber *num;
  NSString *str;
  num = [props objectForKey:NSFilePosixPermissions];
  if (num) {
    info.st_mode = (mode_t)[num unsignedLongValue];
  } else {
    /* 0755 */
    info.st_mode = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;
  }
  /* User ID */
  info.st_uid = geteuid();
  num = [props objectForKey:NSFileOwnerAccountID];
  if (num) {
    info.st_uid = (uid_t)[num unsignedLongValue];
  } else if ((str = [props objectForKey:NSFileOwnerAccountName])) {
    struct passwd *pwd = getpwnam([str UTF8String]);
    if (pwd) {
      info.st_uid = pwd->pw_uid;
    }
  }
  /* Group ID */
  info.st_gid = getegid();
  num = [props objectForKey:NSFileGroupOwnerAccountID];
  if (num) {
    info.st_gid = (gid_t)[num unsignedLongValue];
  } else if ((str = [props objectForKey:NSFileGroupOwnerAccountName])) {
    struct group *grp = getgrnam([str UTF8String]);
    if (grp) {
      info.st_gid = grp->gr_gid;
    }
  }
  
  /* Modification Date */
  NSDate *date = [props objectForKey:NSFileModificationDate];
  if (date) {
    info.st_mtime = lround([date timeIntervalSince1970]);
  } else {
    struct timeval t;
    gettimeofday(&t, NULL);
    info.st_mtime = t.tv_sec;
  }
  info.st_atime = info.st_mtime;
  info.st_ctime = info.st_mtime;
  
  /* Force file type to directory */
  info.st_mode &= ~S_IFMT;
  info.st_mode |= S_IFDIR;
  
  xar_file_t file = xar_add_folder(sa_arch, [parent file], [name UTF8String], &info);
  return [self sa_addFile:file name:name parent:parent];
}

- (SArchiveFile *)addFileWrapper:(NSFileWrapper *)aWrapper parent:(SArchiveFile *)parent {
  BOOL fsname = YES;
  SArchiveFile *file = nil;
  
  NSString *name = [aWrapper filename];
  if (!name) {
    fsname = NO;
    name = [aWrapper preferredFilename];
  }
  if (!name)
		SPXThrowException(NSInvalidArgumentException, @"Invalid file wrapper name.");
  
  if ([aWrapper isDirectory]) {
    file = [self addFolderWithName:name properties:nil parent:parent];
    /* Add sub wrappers */
    NSFileWrapper *wrapper;
    NSEnumerator *wrappers = [[aWrapper fileWrappers] objectEnumerator];
    while (wrapper = [wrappers nextObject]) {
      [self addFileWrapper:wrapper parent:file];
    }
  } else if ([aWrapper isRegularFile]) {
    file = [self addFileWithName:name content:[aWrapper regularFileContents] parent:parent];
  } else if ([aWrapper isSymbolicLink]) {
		SPXThrowException(NSInvalidArgumentException, @"%s does not currently support symlink", __func__);
  } else {
		SPXThrowException(NSInvalidArgumentException, @"unsupported wrapper type");
  }
  if (fsname) {
    [file setValue:@"fsname" forAttribute:@"type" property:@"name"];
    name = [aWrapper preferredFilename];
    if (name)
      [file setValue:name forProperty:@"preferred-filename"];
  } else {
    [file setValue:@"preferred" forAttribute:@"type" property:@"name"];
  }
  return file;
}

#pragma mark -
- (SArchiveDocument *)documentWithName:(NSString *)name {
  if (!_documents) {
    _documents = [[NSMutableDictionary alloc] init];
    xar_subdoc_t doc = xar_subdoc_first(sa_arch);
    while (doc) {
      NSString *docname = [NSString stringWithUTF8String:xar_subdoc_name(doc)];
      SArchiveDocument *d = [[SArchiveDocument alloc] initWithDocument:doc];
      if (d) {
        [d setName:docname];
        [_documents setObject:d forKey:docname];
        [d release];
      }
      doc = xar_subdoc_next(doc);
    }
  }
  return [_documents objectForKey:name];
}

- (SArchiveDocument *)addDocumentWithName:(NSString *)name {
  if (!name)
		SPXThrowException(NSInvalidArgumentException, @"name MUST not be nil");
  xar_subdoc_t doc = xar_subdoc_new(sa_arch, [name UTF8String]);
  if (doc) {
    SArchiveDocument *document = [[SArchiveDocument alloc] initWithDocument:doc];
    if (document) {
      [document setName:name];
      [_documents setObject:document forKey:name];
    }
    return [document autorelease];
  }
  return nil;
}

- (NSArray *)signatures {
  [self loadSignatures];
  return _signatures;
}
- (SArchiveSignature *)addSignature:(SecIdentityRef)identity {
  return [self addSignature:identity includeCertificate:NO];
}
- (SArchiveSignature *)addSignature:(SecIdentityRef)identity includeCertificate:(BOOL)include {
  SArchiveSignature *sign = [SArchiveSignature signatureWithIdentity:identity archive:sa_arch];
  if (sign) {
    [self loadSignatures];
    [_signatures addObject:sign];
  }
  /* include certificate */
  if (sign && include) {
    SecCertificateRef cert;
    if (noErr == SecIdentityCopyCertificate(identity, &cert)) {
      [sign addCertificate:cert];
      CFRelease(cert);
    }
  }
  return sign;  
}

#pragma mark Extract
- (void)sa_extractAtURL:(NSURL *)dest {
  @autoreleasepool {
    _ok = true;
    _cancel = false;

    /* standardize base path */
    dest = dest.filePathURL.URLByStandardizingPath;

    /* Note: Cannot make IMP caching as this will short-cut interthread messaging */
    bool should = [sa_delegate respondsToSelector:@selector(archive:shouldProcessFile:)];
    bool will = [sa_delegate respondsToSelector:@selector(archive:willProcessFile:)];

    bool did_url = [sa_delegate respondsToSelector:@selector(archive:didExtractFile:atURL:)];

    xar_file_t file = NULL;
    xar_iter_t files = xar_iter_new();
    file = xar_file_first(sa_arch, files);
    while (file && _ok && !_cancel) {
      SArchiveFile *f = [self sa_findFile:file];
      NSAssert(f != NULL, @"Cannot find file object");

      if (!should || [sa_delegate archive:self shouldProcessFile:f]) {
        /* Notify handler */
        if (will)
          [sa_delegate archive:self willProcessFile:f];
        /* process file */
        bool result = false;

        NSURL *fspath = dest ? [dest URLByAppendingPathComponent:f.path] : [NSURL fileURLWithPath:f.path];
        if (dest)
          result = [f extractAtURL:fspath];
        else
          result = [f extract];

        if (result && did_url)
          [sa_delegate archive:self didExtractFile:false atURL:fspath];
      }
      /* prepare next file */
      file = xar_file_next(files);
    }
    xar_iter_free(files);

    /* Notify end of extraction */
    if ([sa_delegate respondsToSelector:@selector(archive:didExtractContent:atURL:)])
      [sa_delegate archive:self didExtractContent:(_ok && !_cancel) atURL:dest];
  }
}

- (BOOL)extractAtURL:(NSURL *)anURL handler:(id<SArchiveHandler>)handler {
  if (!OSAtomicCompareAndSwap32(0, 1, &_extracting))
		SPXThrowException(NSInternalInconsistencyException, @"%@ is already extracting data", self);
  
  /* preload archive (if not already done) */
  [self loadTOC];
  sa_delegate = [handler retain];
  
  [self sa_extractAtURL:anURL];

  /* release handler */
  [sa_delegate release];
  sa_delegate = nil;
  _extracting = 0;
  
  return _ok && !_cancel;
}

/* cancel background extraction */
- (void)cancel {
  _cancel = true;
}

NSString * const SArchiveErrorDomain = @"org.shadowlab.sarchive.error";

- (int32_t)handleError:(int32_t)instance severity:(int32_t)severity context:(xar_errctx_t)errctxt {
  /* ignore error if we are not extracting an archive */
  if (!sa_delegate || ![sa_delegate respondsToSelector:@selector(archive:shouldProceedAfterError:severity:)]) {
		_ok = severity <= XAR_SEVERITY_WARNING ? 1 : 0;
    return 0;
	}
  
  int err = xar_err_get_errno(errctxt);
  xar_file_t f = xar_err_get_file(errctxt);
  const char *str = xar_err_get_string(errctxt);
  
  if (!f) {
    SPXDebug(@"Cannot retreive error file");
    return 0;
  }
  
  SArchiveFile *file = [self sa_findFile:f];
  NSAssert(file, @"file not found in archive");
  
  NSMutableDictionary *infos = [[NSMutableDictionary alloc] init];
  [infos setObject:[NSString stringWithUTF8String:str] forKey:NSLocalizedDescriptionKey];
  [infos setObject:@(err) forKey:NSUnderlyingErrorKey];
  [infos setObject:[file path] forKey:NSFilePathErrorKey];
  [infos setObject:file forKey:@"ArchiveFile"];
  
  NSError *error = [[NSError alloc] initWithDomain:SArchiveErrorDomain code:instance userInfo:infos];
  [infos release];
  
  switch(severity) {
    case XAR_SEVERITY_DEBUG:
    case XAR_SEVERITY_INFO:
		case XAR_SEVERITY_NORMAL:
    case XAR_SEVERITY_WARNING:
    case XAR_SEVERITY_NONFATAL:
      _ok = [sa_delegate archive:self shouldProceedAfterError:error severity:severity] ? 1 : 0;
      break;
    case XAR_SEVERITY_FATAL:
      /* call handler but ignore the response */
      [sa_delegate archive:self shouldProceedAfterError:error severity:severity];
      _ok = 0;
      break;
  }
  [error release];
  return 0;
}

@end

int32_t sa_xar_err_handler(int32_t severity, int32_t instance, xar_errctx_t errctxt, void *userctxt) {
  SArchive *archive = (SArchive *)userctxt;
  return [archive handleError:instance severity:severity context:errctxt];
}


