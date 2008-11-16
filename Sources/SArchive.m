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

/* set the toc checksum algorithm */
NSString * const SArchiveOptionTocCheckSumKey = @XAR_OPT_TOCCKSUM;
/* set the file checksum algorithm */
NSString * const SArchiveOptionFileCheckSumKey = @XAR_OPT_FILECKSUM;

NSString * const SArchiveOptionCheckSumNone = @XAR_OPT_VAL_NONE;
NSString * const SArchiveOptionCheckSHA1 = @XAR_OPT_VAL_SHA1;
NSString * const SArchiveOptionCheckMD5 = @XAR_OPT_VAL_MD5;

/* set the file compression type */
NSString * const SArchiveOptionCompressionKey = @XAR_OPT_COMPRESSION;

NSString * const SArchiveOptionCompressionGZip = @XAR_OPT_VAL_GZIP;
NSString * const SArchiveOptionCompressionBZip = @XAR_OPT_VAL_BZIP;

/* include - exclude */
NSString * const SArchiveOptionIncludedProperty = @XAR_OPT_PROPINCLUDE;
NSString * const SArchiveOptionExcludedProperty = @XAR_OPT_PROPEXCLUDE;

//#define XAR_OPT_RSIZE       "rsize"       /* Read io buffer size */
//
//#define XAR_OPT_COALESCE    "coalesce"    /* Coalesce identical heap blocks */
//#define XAR_OPT_LINKSAME    "linksame"    /* Hardlink identical files */


static
int32_t sa_xar_err_handler(int32_t severit, int32_t err, xar_errctx_t ctx, void *usrctx);

@interface SArchiveEnumerator : NSEnumerator {
  NSMapEnumerator sa_enumerator;
}

- (id)initWithMapTable:(NSMapTable *)table;

@end

#pragma mark -
@implementation SArchive

- (id)initWithArchiveAtPath:(NSString *)path {
  return [self initWithArchiveAtPath:path write:NO];
}

- (id)initWithArchiveAtPath:(NSString *)path write:(BOOL)flag {
  if (self = [super init]) {
    sa_arch = (void *)xar_open([path fileSystemRepresentation], flag ? WRITE : READ);
    if (!sa_arch) {
      [self release];
      self = nil;
    } else {
      sa_path = [path copy];
      xar_register_errhandler(sa_arch, sa_xar_err_handler, self);
      sa_files = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
    }
  }
  return self;
}

- (void)dealloc {
  if (sa_arch) {
    [self close];
  }
  [sa_path release];
  [super dealloc];
}

#pragma mark -
- (SArchiveFile *)sa_findFile:(xar_file_t)file {
  return file ? NSMapGet(sa_files, file) : nil;
}
- (SArchiveFile *)sa_addFile:(xar_file_t)file name:(NSString *)name parent:(SArchiveFile *)parent {
  SArchiveFile *f = nil;
  if (file) {
    f = [[SArchiveFile alloc] initWithArchive:sa_xar file:file];
    if (f) {
      [f setName:name];
      NSMapInsert(sa_files, file, f);
      if (parent)
        [parent addFile:f];
      else
        [sa_roots addObject:f];
    }
  }
  return [f autorelease];
}

- (void)loadTOC {
  if (!sa_roots) {
    sa_roots = [[NSMutableArray alloc] init];
    xar_file_t file = NULL;
    xar_iter_t files = xar_iter_new();
    file = xar_file_first(sa_xar, files);
    while (file) {
      SArchiveFile *f = [self sa_findFile:file];
      if (!f) {
        SArchiveFile *p = [self sa_findFile:xar_file_get_parent(file)];
        f = [self sa_addFile:file name:nil parent:p];
      }
      if (f && ![f name]) {
        [f setName:SArchiveXarFileGetProperty(file, @"name")];
      }
      file = xar_file_next(files);
    }
    xar_iter_free(files);
  } 
}
- (void)loadSignatures {
  if (!sa_signatures) {
    sa_signatures = [[NSMutableArray alloc] init];
    xar_signature_t sign = xar_signature_first(sa_arch);
    while (sign) {
      SArchiveSignature *asign = [[SArchiveSignature alloc] initWithArchive:sa_arch signature:sign];
      [sa_signatures addObject:asign];
      [asign release];
      sign = xar_signature_next(sign);
    }
  }
}

- (NSString *)path {
  return sa_path;
}

- (void)close {
  if (sa_arch) {
    xar_close(sa_xar);
    sa_arch = NULL;
    if (sa_files) {
      NSFreeMapTable(sa_files);
      sa_files = NULL;
    }
    [sa_roots release];
    sa_roots = nil;
    
    [sa_documents release];
    sa_documents = nil;
    
    [sa_signatures release]; 
    sa_signatures = nil;
  }
}

- (NSArray *)files {
  [self loadTOC];
  return sa_roots;
}

- (UInt64)size {
  [self loadTOC];
  UInt64 size = 0;
  SArchiveFile *file;
  NSMapEnumerator files = NSEnumerateMapTable(sa_files);
  while (NSNextMapEnumeratorPair(&files, NULL, (void **)&file)) {
    size += [file size];
  }
  NSEndMapTableEnumeration(&files);
  return size;
}

- (NSUInteger)fileCount {
  [self loadTOC];
  return NSCountMapTable(sa_files);
}

- (NSEnumerator *)fileEnumerator {
  [self loadTOC];
  return [[[SArchiveEnumerator alloc] initWithMapTable:sa_files] autorelease];
}

- (SArchiveFile *)fileWithName:(NSString *)name {
  NSArray *files = [self files];
  NSUInteger cnt = [files count];
  while (cnt-- > 0) {
    SArchiveFile *file = [files objectAtIndex:cnt];
    if ([[file name] isEqualToString:name])
      return file;
  }
  return nil;
}

#pragma mark Options
- (void)includeProperty:(NSString *)name {
  [self setValue:name forOption:SArchiveOptionIncludedProperty];
}
- (void)excludeProperty:(NSString *)name {
  [self setValue:name forOption:SArchiveOptionExcludedProperty];
}
- (NSString *)valueForOption:(NSString *)key {
  const char *opt = xar_opt_get(sa_xar, [key UTF8String]);
  if (opt)
    return [NSString stringWithUTF8String:opt];
  return nil;
}

- (void)setValue:(NSString *)opt forOption:(NSString *)key {
  xar_opt_set(sa_xar, [key UTF8String], [opt UTF8String]);
}

- (BOOL)boolValueForOption:(NSString *)key {
  const char *opt = xar_opt_get(sa_xar, [key UTF8String]);
  if (opt) return 0 == strcmp(opt, XAR_OPT_VAL_TRUE);
  return NO;
}
- (void)setBoolValue:(BOOL)value forOption:(NSString *)key {
  xar_opt_set(sa_xar, [key UTF8String], value ? XAR_OPT_VAL_TRUE : XAR_OPT_VAL_FALSE);
}

- (SArchiveFile *)addFile:(NSString *)path {
  xar_file_t file = xar_add(sa_xar, [path fileSystemRepresentation]);
  return [self sa_addFile:file name:nil parent:file ? [self sa_findFile:xar_file_get_parent(file)] : NULL];
}

- (SArchiveFile *)addFile:(NSString *)path name:(NSString *)name parent:(SArchiveFile *)parent {
  xar_file_t file = xar_add_frompath(sa_xar, [parent file], [name UTF8String], [path fileSystemRepresentation]);
  return [self sa_addFile:file name:name parent:parent];
}

- (SArchiveFile *)addFile:(NSString *)name data:(NSData *)data parent:(SArchiveFile *)parent {
  xar_file_t file = xar_add_frombuffer(sa_xar, [parent file], [name UTF8String], [data bytes], [data length]);
  SArchiveFile *f = [self sa_addFile:file name:name parent:parent];
  if (f)
    [f setPosixPermissions:0644];
  return f;
}

- (SArchiveFile *)addFolder:(NSString *)name properties:(NSDictionary *)props parent:(SArchiveFile *)parent {
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
  } else if (str = [props objectForKey:NSFileOwnerAccountName]) {
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
  } else if (str = [props objectForKey:NSFileGroupOwnerAccountName]) {
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
  
  xar_file_t file = xar_add_folder(sa_xar, [parent file], [name UTF8String], &info);
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
		WBThrowException(NSInvalidArgumentException, @"Invalid file wrapper name.");
  
  if ([aWrapper isDirectory]) {
    file = [self addFolder:name properties:nil parent:parent];
    /* Add sub wrappers */
    NSFileWrapper *wrapper;
    NSEnumerator *wrappers = [[aWrapper fileWrappers] objectEnumerator];
    while (wrapper = [wrappers nextObject]) {
      [self addFileWrapper:wrapper parent:file];
    }
  } else if ([aWrapper isRegularFile]) {
    file = [self addFile:name data:[aWrapper regularFileContents] parent:parent];
  } else if ([aWrapper isSymbolicLink]) {
		WBThrowException(NSInvalidArgumentException, @"%@ does not currently support symlink", NSStringFromSelector(_cmd));
  } else {
		WBThrowException(NSInvalidArgumentException, @"unsupported wrapper type");
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
  if (!sa_documents) {
    sa_documents = [[NSMutableDictionary alloc] init];
    xar_subdoc_t doc = xar_subdoc_first(sa_xar);
    while (doc) {
      NSString *docname = [NSString stringWithUTF8String:xar_subdoc_name(doc)];
      SArchiveDocument *d = [[SArchiveDocument alloc] initWithArchive:sa_xar document:doc];
      if (d) {
        [d setName:docname];
        [sa_documents setObject:d forKey:docname];
        [d release];
      }
      doc = xar_subdoc_next(doc);
    }
  }
  return [sa_documents objectForKey:name];
}

- (SArchiveDocument *)addDocumentWithName:(NSString *)name {
  if (!name)
		WBThrowException(NSInvalidArgumentException, @"name MUST not be nil");
  xar_subdoc_t doc = xar_subdoc_new(sa_xar, [name UTF8String]);
  if (doc) {
    SArchiveDocument *document = [[SArchiveDocument alloc] initWithArchive:sa_xar document:doc];
    if (document) {
      [document setName:name];
      [sa_documents setObject:document forKey:name];
    }
    return [document autorelease];
  }
  return nil;
}

- (NSArray *)signatures {
  [self loadSignatures];
  return sa_signatures;
}
- (SArchiveSignature *)addSignature:(SecIdentityRef)identity {
  return [self addSignature:identity includeCertificate:NO];
}
- (SArchiveSignature *)addSignature:(SecIdentityRef)identity includeCertificate:(BOOL)include {
  SArchiveSignature *sign = [SArchiveSignature signatureWithIdentity:identity archive:sa_arch];
  if (sign) {
    [self loadSignatures];
    [sa_signatures addObject:sign];
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
- (void)sa_extractToPath:(NSString *)dest {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  sa_arFlags.ok = 1;
  sa_arFlags.cancel = 0;
  
  /* standardize base path */
  dest = [dest stringByStandardizingPath];
  
  /* Note: Cannot make IMP caching as this will short-cut interthread messaging */
  bool should = [sa_delegate respondsToSelector:@selector(archive:shouldProcessFile:)];
  bool will = [sa_delegate respondsToSelector:@selector(archive:willProcessFile:)];
  bool did = [sa_delegate respondsToSelector:@selector(archive:didProcessFile:path:)];
  
  xar_file_t file = NULL;
  xar_iter_t files = xar_iter_new();
  file = xar_file_first(sa_xar, files);
  while (file && sa_arFlags.ok && !sa_arFlags.cancel) {
    SArchiveFile *f = [self sa_findFile:file];
    NSAssert(f != NULL, @"Cannot find file object");
    
    if (!should || [sa_delegate archive:self shouldProcessFile:f]) {
      /* Notify handler */
      if (will) [sa_delegate archive:self willProcessFile:f];
      /* process file */
      bool result = false;
      
      NSString *fspath = dest ? [dest stringByAppendingPathComponent:[f path]] : [f path];
      if (dest)
        result = [f extractToPath:fspath];
      else
        result = [f extract];
      
      if (result && did) [sa_delegate archive:self didProcessFile:f path:fspath];
    }
    /* prepare next file */
    file = xar_file_next(files);
  }
  xar_iter_free(files);
  
  /* Notify end of extraction */
  if ([sa_delegate respondsToSelector:@selector(archive:didExtract:path:)])
    [sa_delegate archive:self didExtract:(sa_arFlags.ok && !sa_arFlags.cancel) path:dest];
  
  /* release handler */
  [sa_delegate release];
  sa_delegate = nil;
  sa_extract = 0;
  [pool release];
}

- (BOOL)extractToPath:(NSString *)path handler:(id)handler {
  if (!OSAtomicCompareAndSwap32(0, 1, &sa_extract))
		WBThrowException(NSInternalInconsistencyException, @"%@ is already extracting data");
  
  /* preload archive (if not already done) */
  [self loadTOC];
  sa_delegate = [handler retain];
  
  [self sa_extractToPath:path];
  
  return sa_arFlags.ok && !sa_arFlags.cancel;
}

/* cancel background extraction */
- (void)cancel {
  sa_arFlags.cancel = 1;
}

NSString * const SArchiveErrorDomain = @"org.shadowlab.sarchive.error";

- (int32_t)handleError:(int32_t)instance severity:(int32_t)severity context:(xar_errctx_t)errctxt {
  /* ignore error if we are not extracting an archive */
  if (!sa_delegate || ![sa_delegate respondsToSelector:@selector(archive:shouldProceedAfterError:severity:)]) {
		sa_arFlags.ok = severity <= XAR_SEVERITY_WARNING ? 1 : 0;
    return 0;
	}
  
  int err = xar_err_get_errno(errctxt);
  xar_file_t f = xar_err_get_file(errctxt);
  const char *str = xar_err_get_string(errctxt);
  
  if (!f) {
    DLog(@"Cannot retreive error file");
    return 0;
  }
  
  SArchiveFile *file = [self sa_findFile:f];
  NSAssert(file, @"file not found in archive");
  
  NSMutableDictionary *infos = [[NSMutableDictionary alloc] init];
  [infos setObject:[NSString stringWithCString:str] forKey:NSLocalizedDescriptionKey];
  [infos setObject:WBInteger(err) forKey:NSUnderlyingErrorKey];
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
      sa_arFlags.ok = [sa_delegate archive:self shouldProceedAfterError:error severity:severity] ? 1 : 0;
      break;
    case XAR_SEVERITY_FATAL:
      /* call handler but ignore the response */
      [sa_delegate archive:self shouldProceedAfterError:error severity:severity];
      sa_arFlags.ok = 0;
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

#pragma mark -
@implementation SArchiveEnumerator

- (id)initWithMapTable:(NSMapTable *)table {
  NSParameterAssert(table);
  if (self = [super init]) {
    sa_enumerator = NSEnumerateMapTable(table);
  }
  return self;
}

- (void)dealloc {
  NSEndMapTableEnumeration(&sa_enumerator);
  [super dealloc];
}

- (id)nextObject {
  void *object = NULL;
  if (NSNextMapEnumeratorPair(&sa_enumerator, NULL, &object)) {
    return object;
  }
  NSEndMapTableEnumeration(&sa_enumerator);
  return nil;
}

/* Warning: a map can contains something that's not an NSObject (ie: integer) */
- (NSArray *)allObjects {
  id object = nil;
  NSMutableArray *objects = [[NSMutableArray alloc] init];
  while (object = [self nextObject]) {
    [objects addObject:object];
  }
  return [objects autorelease];
}

@end

