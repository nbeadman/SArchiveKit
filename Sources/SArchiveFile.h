/*
 *  SArchiveFile.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SABase.h>

enum {
  kSArchiveTypeUndefined = 0,
  kSArchiveTypeFile,
  kSArchiveTypeSymlink,
  kSArchiveTypeDirectory,
  /* Other types */
  kSArchiveTypeFifo,
  kSArchiveTypeSocket,
  kSArchiveTypeBlockSpecial,
  kSArchiveTypeCharacterSpecial,
  /* Misc */
  kSArchiveTypeWithout,
};

SA_CLASS_EXPORT
@interface SArchiveFile : NSObject {
@private
  void *sa_ptr;
  void *sa_arch;
  NSString *sa_name;
  NSString *sa_path;
  
  SArchiveFile *sa_parent;
  NSMutableArray *sa_files;
}

- (NSString *)path;
- (void)setPath:(NSString *)aPath;

- (NSInteger)type;
- (UInt64)size;

- (NSString *)name;
- (void)setName:(NSString *)aName;

- (mode_t)posixPermissions;
- (void)setPosixPermissions:(mode_t)perm;

- (BOOL)verify;
- (BOOL)extract;
- (NSData *)extractContents;
- (BOOL)extractToPath:(NSString *)path;
//- (BOOL)extractToStream:(NSOutputStream *)aStream handler:(id)handler;

- (NSFileWrapper *)fileWrapper;
- (SArchiveFile *)fileWithName:(NSString *)name;

/* Properties */
- (NSString *)valueForProperty:(NSString *)prop;
- (void)setValue:(NSString *)value forProperty:(NSString *)prop;

/* Attributes */
- (NSString *)valueForAttribute:(NSString *)attr property:(NSString *)prop;
- (void)setValue:(NSString *)value forAttribute:(NSString *)attr property:(NSString *)property;

#pragma mark -
- (SArchiveFile *)container;

- (NSArray *)files;
- (NSUInteger)count;

/* deep enumerator */
- (NSEnumerator *)enumerator;

@end

//@interface NSObject (SArchiveFileHandler)
//- (void)extractingFile:(SArchiveFile *)file progress:(CGFloat)progress;
//@end

