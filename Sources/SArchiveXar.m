/*
 *  SArchiveXar.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import "SArchiveXar.h"

/* Helper macros to avoid duplicate code (for xar_ and xar_subdoc_ families functions) */
#define __SArchiveXarPropertyGet(ptr, property, getter) { \
  NSString *str = nil; \
  if (ptr && property) { \
    const char *value = NULL; \
    if (0 == getter(ptr, [property UTF8String], &value) && value) { \
      str = [NSString stringWithUTF8String:value]; \
    } \
  } \
  return str; \
}

#define __SArchiveXarAttributeGet(ptr, property, attribute, getter) { \
  NSString *str = nil; \
  if (ptr && property && attribute) { \
    const char *value = getter(ptr, [property UTF8String], [attribute UTF8String]); \
    if (value) { \
      str = [NSString stringWithUTF8String:value]; \
    } \
  } \
  return str; \
}

#pragma mark Xar File
NSString *SArchiveXarFileGetProperty(xar_file_t file, NSString *property) {
  __SArchiveXarPropertyGet(file, property, xar_prop_get);
}

NSInteger SArchiveXarFileSetProperty(xar_file_t file, NSString *property, NSString *value) {
  if (file && property)
    return xar_prop_set(file, [property UTF8String], [value UTF8String]);
  return -1;
}

NSString *SArchiveXarFileGetAttribute(xar_file_t file, NSString *property, NSString *attribute) {
  __SArchiveXarAttributeGet(file, property, attribute, xar_attr_get);
}

NSInteger SArchiveXarFileSetAttribute(xar_file_t file, NSString *property, NSString *attribute, NSString *value) {
  if (file && property && attribute)
    return xar_attr_set(file, [property UTF8String], [attribute UTF8String], [value UTF8String]);
  return -1;
}

#pragma mark Xar Sub Document
NSString *SArchiveXarSubDocGetProperty(xar_subdoc_t doc, NSString *property) {
  __SArchiveXarPropertyGet(doc, property, xar_subdoc_prop_get);
}
NSInteger SArchiveXarSubDocSetProperty(xar_subdoc_t doc, NSString *property, NSString *value) {
  if (doc && property)
    return xar_subdoc_prop_set(doc, [property UTF8String], [value UTF8String]);
  return -1;
}

NSString *SArchiveXarSubDocGetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute) {
  __SArchiveXarAttributeGet(doc, property, attribute, xar_subdoc_attr_get);
}
NSInteger SArchiveXarSubDocSetAttribute(xar_subdoc_t doc, NSString *property, NSString *attribute, NSString *value) {
  if (doc && property && attribute)
    return xar_subdoc_attr_set(doc, [property UTF8String], [attribute UTF8String], [value UTF8String]);
  return -1;
}

