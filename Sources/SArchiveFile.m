/*
 *  SArchiveFile.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SArchiveFile.h>

#import "SArchiveXar.h"

@interface _SArchiveFileDeepEnumerator : NSEnumerator {
@protected
  SArchiveFile *sa_root;
  SArchiveFile *sa_node;
}

- (id)initWithRootNode:(SArchiveFile *)node;

@end

@implementation SArchiveFile

- (void)dealloc {
  [self removeAllFiles];
  [sa_files release];
  [sa_path release];
  [sa_name release];
  [super dealloc];
}

#pragma mark -
- (NSString *)path {
  if (!sa_path && sa_file) {
    char *buffer = xar_get_path(sa_file);
    if (buffer) {
      sa_path = [[NSString alloc] initWithUTF8String:buffer];
      free(buffer);
    }
  }
  return sa_path;
}
- (void)setPath:(NSString *)aPath {
  WBSetterCopy(sa_path, aPath);
}

- (NSInteger)type {
  NSString *type = [self valueForProperty:@"type"];
  /* common cases */
  if ([type isEqualToString:@"file"])
    return kSArchiveTypeFile;
  if ([type isEqualToString:@"directory"]) 
    return kSArchiveTypeDirectory;
  if ([type isEqualToString:@"symlink"]) 
    return kSArchiveTypeSymlink;
  
  if ([type isEqualToString:@"fifo"])
    return kSArchiveTypeFifo;
  if ([type isEqualToString:@"socket"]) 
    return kSArchiveTypeSocket;
  if ([type isEqualToString:@"block special"]) 
    return kSArchiveTypeBlockSpecial;
  if ([type isEqualToString:@"character special"])
    return kSArchiveTypeCharacterSpecial;
  
  if ([type isEqualToString:@"whiteout"]) 
    return kSArchiveTypeWithout;
  
  return kSArchiveTypeUndefined;
}

- (UInt64)size {
  if (sa_ptr) {
    const char *sizestring = NULL;
    if(0 == xar_prop_get(sa_file, "data/size", &sizestring)) {
      return strtoull(sizestring, (char **)NULL, 10);
    }
  }
  return 0;
}

- (NSString *)name {
  if (!sa_name && sa_file) {
    sa_name = [[self valueForProperty:@"name"] retain];
  }
  return sa_name;
}
- (void)setName:(NSString *)aName {
  WBSetterCopy(sa_name, aName);
}

- (mode_t)posixPermissions {
  mode_t mode = 0;
  NSString *str = [self valueForProperty:@"mode"];
  if (str) {
    const char *cstr = [str UTF8String];
    if (cstr) {
      mode = strtol(cstr, NULL, 8);
    }
  }
  return mode;
}

- (void)setPosixPermissions:(mode_t)perm {
  NSString *str = [[NSString alloc] initWithFormat:@"%.4lo", perm];
  if (str) {
    [self setValue:str forProperty:@"mode"];
    [str release];
  }
}

- (BOOL)verify {
  return 0 == xar_verify(sa_xar, sa_file);
}

- (BOOL)extract {
  return 0 == xar_extract(sa_xar, sa_file);
}

- (BOOL)extractToPath:(NSString *)path {
  return 0 == xar_extract_tofile(sa_xar, sa_file, [path fileSystemRepresentation]);
}

//- (BOOL)extractToStream:(NSOutputStream *)aStream handler:(id)handler {
//  xar_stream stream;
//  bzero(&stream, sizeof(stream));
//  int err = xar_extract_tostream_init(sa_xar, sa_file, &stream);
//  if (XAR_STREAM_OK == err) {
//    UInt64 size = [self size];
//    //err = xar_extract_tostream(<#xar_stream * stream#>)
//    
//    /* release resources */
//    xar_extract_tostream_end(&stream);
//  }
//  return XAR_STREAM_END == err;
//}

- (NSData *)extractContents {
  size_t size = 0;
  NSData *data = nil;
  char *buffer = NULL;
  if (0 != xar_extract_tobuffersz(sa_xar, sa_file, &buffer, &size)) {
    if (buffer) free(buffer);
  } else if (buffer) {
    data = [NSData dataWithBytesNoCopy:buffer length:size freeWhenDone:YES];
  }
  return data;
}

- (NSFileWrapper *)fileWrapper {
  NSFileWrapper *file = nil;
  switch ([self type]) {
    case kSArchiveTypeDirectory: {
      NSMutableDictionary *wrappers = [NSMutableDictionary dictionary];
      /* get childrens */
      NSUInteger count = [sa_files count];
      for (NSUInteger idx = 0; idx < count; idx++) {
        SArchiveFile *child = [sa_files objectAtIndex:idx];
        NSFileWrapper *wchild = [child fileWrapper];
        NSString *key = [wchild preferredFilename];
        if (!key) key = [wchild filename];
        if (key)
          [wrappers setObject:wchild forKey:key];
      }
      file = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:wrappers];
    }
      break;
    case kSArchiveTypeFile: {
      NSData *data = [self extractContents];
      file = [[NSFileWrapper alloc] initRegularFileWithContents:data];
    }
      break;
    default:
			WBThrowException(NSInvalidArgumentException, @"cannot create filewrapper with type: %@", [self valueForProperty:@"type"]);
  }
  /* Restore attributes */
  NSString *nametype = [self valueForAttribute:@"type" property:@"name"];
  if (!nametype || [nametype isEqualToString:@"fsname"]) {
    [file setFilename:[self valueForProperty:@"name"]];
    NSString *pname = [self valueForProperty:@"preferred-filename"];
    if (pname) {
      [file setPreferredFilename:pname];
    }
  } else {
    [file setPreferredFilename:[self valueForProperty:@"name"]];
  }
  return [file autorelease];
}

- (SArchiveFile *)fileWithName:(NSString *)name {
  NSUInteger idx = [sa_files count];
  while (idx-- > 0) {
    SArchiveFile *file = [sa_files objectAtIndex:idx];
    if ([[file name] isEqualToString:name])
      return file;
  }
  return nil;
}

/* Properties */
- (NSString *)valueForProperty:(NSString *)prop {
  return SArchiveXarFileGetProperty(sa_file, prop);
}
- (void)setValue:(NSString *)value forProperty:(NSString *)prop {
  SArchiveXarFileSetProperty(sa_file, prop, value);
}

/* Attributes */
- (NSString *)valueForAttribute:(NSString *)attr property:(NSString *)prop {
  return SArchiveXarFileGetAttribute(sa_file, prop, attr);
}
- (void)setValue:(NSString *)value forAttribute:(NSString *)attr property:(NSString *)property {
  SArchiveXarFileSetAttribute(sa_file, property, attr, value);
}

#pragma mark -
- (NSMutableArray *)sa_files {
  if (!sa_files)
    sa_files = [[NSMutableArray alloc] init];
  return sa_files;
}

- (SArchiveFile *)container {
  return sa_parent;
}
- (void)setContainer:(SArchiveFile *)container {
  sa_parent = container;
}



- (NSArray *)files {
  return sa_files;
}
- (NSUInteger)count {
  return [sa_files count];
}

- (NSEnumerator *)enumerator {
  return [[[_SArchiveFileDeepEnumerator alloc] initWithRootNode:self] autorelease];
}

#pragma mark -
#pragma mark Xar Interface

- (id)initWithArchive:(xar_t)arch file:(xar_file_t)ptr {
  if (self = [super init]) {
    [self setFile:ptr];
    [self setArchive:arch];
  }
  return self;
}

- (xar_file_t)file {
  return sa_file;
}
- (void)setFile:(xar_file_t)file {
  sa_ptr = (void *)file;
}

- (xar_t)archive {
  return sa_xar;
}
- (void)setArchive:(xar_t)arch {
  sa_arch = (void *)arch;
}

- (void)addFile:(SArchiveFile *)aFile {
  NSParameterAssert(nil == [aFile container]);
  [aFile setContainer:self];
  [[self sa_files] addObject:aFile];
}
//- (void)removeFile:(SArchiveFile *)aFile {
//  NSUInteger idx = [sa_files indexOfObject:aFile];
//  if (idx != NSNotFound) {
//    [self removeFileAtIndex:idx];
//  }
//}
- (void)removeAllFiles {
  if (sa_files) {
    [sa_files makeObjectsPerformSelector:@selector(setContainer:) withObject:nil];
    [sa_files removeAllObjects];
  }
}
- (SArchiveFile *)fileAtIndex:(NSUInteger)anIndex {
  return [sa_files objectAtIndex:anIndex];
}
//- (void)removeFileAtIndex:(NSUInteger)anIndex {
//  SArchiveFile *file = [sa_files objectAtIndex:anIndex];
//  [file setContainer:nil];
//  [sa_files removeObjectAtIndex:anIndex];
//}
//- (void)insertFile:(SArchiveFile *)aFile atIndex:(NSUInteger)anIndex {
//  NSParameterAssert(nil == [aFile container]);
//  [[self sa_files] insertObject:aFile atIndex:anIndex];
//  [aFile setContainer:self];
//}

@end

#pragma mark -
@implementation _SArchiveFileDeepEnumerator

- (id)initWithRootNode:(SArchiveFile *)node {
  if (self = [super init]) {
    if ([node count] > 0) {
      sa_root = [node retain];
      sa_node = [sa_root fileAtIndex:0];
    }
  }
  return self;
}

- (void)dealloc {
  [sa_root release];
  [super dealloc];
}

SA_INLINE
SArchiveFile *__WBNextFile(SArchiveFile *file) {
  SArchiveFile *parent = [file container];
  if (parent) {
    NSArray *files = [parent files];
    NSUInteger idx = [files indexOfObjectIdenticalTo:file];
    if (idx != NSNotFound && (idx + 1) < [files count])
      return [files objectAtIndex:idx + 1];
  }
  return nil;
}

- (id)nextObject {
  SArchiveFile *node = sa_node;
  /* End was reached */
  if (!node) {
    [sa_root release];
    sa_root = nil;
  }
  /* Go one level deeper */
  if ([sa_node count] == 0) {
    /* Si on ne peut pas descendre on se deplace lateralement */
    SArchiveFile *sibling = nil;
    /* Tant qu'on est pas remonte en haut de l'arbre, et qu'on a pas trouvé de voisin */
    while (sa_node && sa_node != sa_root && !(sibling = __WBNextFile(sa_node))) {
      sa_node = [sa_node container];
    }
    sa_node = sibling;
  } else {
    sa_node = [sa_node fileAtIndex:0];
  }
  return node;
}

- (NSArray *)allObjects {
  if (!sa_node) { return [NSArray array]; }
  
  NSMutableArray *children = [NSMutableArray array];
  SArchiveFile *node = nil;
  while (node = [self nextObject]) {
    [children addObject:node];
  }
  return children;
}

@end

