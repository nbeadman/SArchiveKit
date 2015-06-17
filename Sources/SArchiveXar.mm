/*
 *  SArchiveXar.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import "SArchiveXar.h"

/* Helper functions to avoid duplicate code (for xar_ and xar_subdoc_ families functions) */
template<class Ty, int32_t (*Get)(Ty, const char *, const char **)>
static inline
NSString *__SArchiveXarPropertyGet(Ty ptr, NSString *property) {
    NSString *str = nil;
    if (ptr && property) {
        const char *value = NULL;
        if (0 == Get(ptr, [property UTF8String], &value) && value) {
            str = [NSString stringWithUTF8String:value];
        }
    }
    return str;
}

template<class Ty, const char *(*Get)(Ty, const char *, const char *)>
static inline
NSString *__SArchiveXarAttributeGet(Ty ptr, NSString *property, NSString *attribute) {
  NSString *str = nil;
  if (ptr && property && attribute) {
    const char *value = Get(ptr, [property UTF8String], [attribute UTF8String]);
    if (value) {
      str = [NSString stringWithUTF8String:value];
    }
  }
  return str;
}

#pragma mark Xar File
NSString *SArchiveXarFileGetProperty(xar_file_t file, NSString *property) {
  return __SArchiveXarPropertyGet<xar_file_t, xar_prop_get>(file, property);
}

NSInteger SArchiveXarFileSetProperty(xar_file_t file, NSString *property, NSString *value) {
  if (file && property)
    return xar_prop_set(file, [property UTF8String], [value UTF8String]);
  return -1;
}

NSString *SArchiveXarFileGetAttribute(xar_file_t file, NSString *property, NSString *attribute) {
  return __SArchiveXarAttributeGet<xar_file_t, xar_attr_get>(file, property, attribute);
}

NSInteger SArchiveXarFileSetAttribute(xar_file_t file, NSString *property, NSString *attribute, NSString *value) {
  if (file && property && attribute)
    return xar_attr_set(file, [property UTF8String], [attribute UTF8String], [value UTF8String]);
  return -1;
}

#pragma mark Xar Sub Document
NSString *SArchiveXarSubDocGetProperty(xar_subdoc_t doc, NSString *property) {
  return __SArchiveXarPropertyGet<xar_subdoc_t, xar_subdoc_prop_get>(doc, property);
}
NSInteger SArchiveXarSubDocSetProperty(xar_subdoc_t doc, NSString *property, NSString *value) {
  if (doc && property)
    return xar_subdoc_prop_set(doc, [property UTF8String], [value UTF8String]);
  return -1;
}

NSString *SArchiveXarSubDocGetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute) {
  return __SArchiveXarAttributeGet<xar_subdoc_t, xar_subdoc_attr_get>(doc, property, attribute);
}
NSInteger SArchiveXarSubDocSetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute, NSString *value) {
  if (doc && property && attribute)
    return xar_subdoc_attr_set(doc, [property UTF8String], [attribute UTF8String], [value UTF8String]);
  return -1;
}

