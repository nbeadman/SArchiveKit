/*
 *  SArchiveDocument.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SArchiveDocument.h>

#import "SArchiveXar.h" 

@implementation SArchiveDocument

- (void)dealloc {
  [sa_name release];
  [super dealloc];
}

#pragma mark -
- (NSString *)name {
  if (!sa_name && sa_doc) {
    const char *name = xar_subdoc_name(sa_doc);
    if (name)
      sa_name = [[NSString alloc] initWithUTF8String:name];
  }
  return sa_name;
}
- (void)setName:(NSString *)aName {
  WBSetterCopy(&sa_name, aName);
}

/* Properties */
- (NSString *)valueForProperty:(NSString *)prop {
  return SArchiveXarSubDocGetProperty(sa_doc, prop);
}
- (void)setValue:(NSString *)value forProperty:(NSString *)prop {
  SArchiveXarSubDocSetProperty(sa_doc, prop, value);
}

/* Attributes */
- (NSString *)valueForAttribute:(NSString *)attr property:(NSString *)prop {
  return SArchiveXarSubDocGetAttribute(sa_doc, prop, attr);
}
- (void)setValue:(NSString *)value forAttribute:(NSString *)attr property:(NSString *)property {
  SArchiveXarSubDocSetAttribute(sa_doc, property, attr, value);
}

#pragma mark Xar Interface

- (id)initWithArchive:(xar_t)arch document:(xar_subdoc_t)ptr {
  if (self = [super init]) {
    [self setDocument:ptr];
    [self setArchive:arch];
  }
  return self;
}

- (xar_subdoc_t)document {
  return sa_doc;
}
- (void)setDocument:(xar_subdoc_t)doc {
  sa_ptr = (void *)doc;
}

- (xar_t)archive {
  return sa_xar;
}
- (void)setArchive:(xar_t)arch {
  sa_arch = (void *)arch;
}

@end
