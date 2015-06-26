/*
 *  SArchiveXar.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#if defined(__cplusplus)
extern "C" {
#endif

#include "xar.h"

#if defined(__cplusplus)
}
#endif

#import <SArchiveKit/SABase.h>

SARCHIVE_PRIVATE
xar_file_t xar_file_get_parent(xar_file_t file);

SARCHIVE_PRIVATE
NSString *SArchiveXarFileGetProperty(xar_file_t file, NSString *property);
SARCHIVE_PRIVATE
NSInteger SArchiveXarFileSetProperty(xar_file_t file, NSString *property, NSString *value);

SARCHIVE_PRIVATE
NSString *SArchiveXarFileGetAttribute(xar_file_t file, NSString *property, NSString *attribute);
SARCHIVE_PRIVATE
NSInteger SArchiveXarFileSetAttribute(xar_file_t file, NSString *property, NSString *attribute, NSString *value);

SARCHIVE_PRIVATE
NSString *SArchiveXarSubDocGetProperty(xar_subdoc_t doc, NSString *property);
SARCHIVE_PRIVATE
NSInteger SArchiveXarSubDocSetProperty(xar_subdoc_t doc, NSString *property, NSString *value);

SARCHIVE_PRIVATE
NSString *SArchiveXarSubDocGetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute);
SARCHIVE_PRIVATE
NSInteger SArchiveXarSubDocSetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute, NSString *value);

#pragma mark -
#import <SArchiveKit/SArchiveFile.h>
#import <SArchiveKit/SArchiveDocument.h>
#import <SArchiveKit/SArchiveSignature.h>

SARCHIVE_INLINE
const char *SArchiveGetPath(NSURL *url, bool resolve) {
  if (!url)
    return NULL;
  if (resolve && [url isFileReferenceURL])
    url = url.filePathURL;
  if (NSFoundationVersionNumber >= NSFoundationVersionNumber10_9)
    return url.fileSystemRepresentation;
  return url.path.fileSystemRepresentation;
}

@interface SArchiveFile ()

- (instancetype)initWithArchive:(xar_t)arch file:(xar_file_t)ptr;

@property(nonatomic, readonly) xar_file_t file;

@property(nonatomic, readonly) xar_t archive;

- (void)addFile:(SArchiveFile *)aFile;
- (SArchiveFile *)fileAtIndex:(NSUInteger)anIndex;

//- (void)removeFile:(SArchiveFile *)aFile;

- (void)removeAllFiles;

//- (void)removeFileAtIndex:(NSUInteger)anIndex;
//- (void)insertFile:(SArchiveFile *)aFile atIndex:(NSUInteger)anIndex;

@end

@interface SArchiveDocument ()

- (instancetype)initWithDocument:(xar_subdoc_t)ptr;

@property(nonatomic, readonly) xar_subdoc_t document;

@end

@interface SArchiveSignature ()

+ (SArchiveSignature *)signatureWithIdentity:(SecIdentityRef)identity archive:(xar_t)arch;
- (instancetype)initWithSignature:(xar_signature_t)ptr;

@property(nonatomic, readonly) xar_signature_t signature;


@end

