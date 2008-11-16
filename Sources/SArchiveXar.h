/*
 *  SArchiveXar.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#include "xar.h"

WB_PRIVATE
xar_file_t xar_file_get_parent(xar_file_t file);

WB_PRIVATE
NSString *SArchiveXarFileGetProperty(xar_file_t file, NSString *property);
WB_PRIVATE
NSInteger SArchiveXarFileSetProperty(xar_file_t file, NSString *property, NSString *value);

WB_PRIVATE
NSString *SArchiveXarFileGetAttribute(xar_file_t file, NSString *property, NSString *attribute);
WB_PRIVATE
NSInteger SArchiveXarFileSetAttribute(xar_file_t file, NSString *property, NSString *attribute, NSString *value);

WB_PRIVATE
NSString *SArchiveXarSubDocGetProperty(xar_subdoc_t doc, NSString *property);
WB_PRIVATE
NSInteger SArchiveXarSubDocSetProperty(xar_subdoc_t doc, NSString *property, NSString *value);

WB_PRIVATE
NSString *SArchiveXarSubDocGetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute);
WB_PRIVATE
NSInteger SArchiveXarSubDocSetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute, NSString *value);

#pragma mark -
#import <SArchiveKit/SArchiveFile.h>
#import <SArchiveKit/SArchiveDocument.h>
#import <SArchiveKit/SArchiveSignature.h>

#define sa_xar  (xar_t)sa_arch
#define sa_file (xar_file_t)sa_ptr
#define sa_doc  (xar_subdoc_t)sa_ptr
#define sa_sign (xar_signature_t)sa_ptr

@interface SArchiveFile ()

- (id)initWithArchive:(xar_t)arch file:(xar_file_t)ptr;

- (xar_file_t)file;
- (void)setFile:(xar_file_t)file;

- (xar_t)archive;
- (void)setArchive:(xar_t)arch;

- (void)addFile:(SArchiveFile *)aFile;
- (SArchiveFile *)fileAtIndex:(NSUInteger)anIndex;
//- (void)removeFile:(SArchiveFile *)aFile;
- (void)removeAllFiles;
//- (void)removeFileAtIndex:(NSUInteger)anIndex;
//- (void)insertFile:(SArchiveFile *)aFile atIndex:(NSUInteger)anIndex;

@end

@interface SArchiveDocument ()

- (id)initWithArchive:(xar_t)arch document:(xar_subdoc_t)ptr;

- (xar_t)archive;
- (void)setArchive:(xar_t)arch;

- (xar_subdoc_t)document;
- (void)setDocument:(xar_subdoc_t)document;

@end

@interface SArchiveSignature ()

+ (SArchiveSignature *)signatureWithIdentity:(SecIdentityRef)identity archive:(xar_t)arch;
- (id)initWithArchive:(xar_t)arch signature:(xar_signature_t)ptr;

- (xar_t)archive;
- (void)setArchive:(xar_t)arch;

- (xar_signature_t)signature;
- (void)setSignature:(xar_signature_t)signature;

- (void)setIndentity:(SecIdentityRef)anIndentity;

@end

