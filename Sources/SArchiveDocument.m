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

- (instancetype)initWithDocument:(xar_subdoc_t)ptr {
  if (self = [super init]) {
    _document = ptr;
  }
  return self;
}

- (void)dealloc {
  [_name release];
  [super dealloc];
}

#pragma mark -
- (NSString *)name {
  if (!_name && _document) {
    const char *name = xar_subdoc_name(_document);
    if (name)
      _name = [[NSString alloc] initWithUTF8String:name];
  }
  return _name;
}

/* Properties */
- (NSString *)valueForProperty:(NSString *)prop {
  return SArchiveXarSubDocGetProperty(_document, prop);
}
- (void)setValue:(NSString *)value forProperty:(NSString *)prop {
  SArchiveXarSubDocSetProperty(_document, prop, value);
}

/* Attributes */
- (NSString *)valueForAttribute:(NSString *)attr property:(NSString *)prop {
  return SArchiveXarSubDocGetAttribute(_document, prop, attr);
}
- (void)setValue:(NSString *)value forAttribute:(NSString *)attr property:(NSString *)property {
  SArchiveXarSubDocSetAttribute(_document, property, attr, value);
}

@end
