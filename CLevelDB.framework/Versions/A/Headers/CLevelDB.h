//
//  CLevelDB.h
//  CLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//
// Copyright (c) 2016 Amr Aboelela <amraboelela@gmail.com>
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

//! Project version number for CLevelDB.
//FOUNDATION_EXPORT double CLevelDBVersionNumber;

//! Project version string for CLevelDB.
//FOUNDATION_EXPORT const unsigned char CLevelDBVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <CLevelDB/PublicHeader.h>



#include <stdbool.h>

#pragma mark - Database

void *levelDBOpen(char *path);
void levelDBDelete(void *db);

#pragma mark - Item

long levelDBItemPut(void *db, char *key, long keyLength, void *data, long dataLength);
long levelDBItemGet(void *db, char *key, long keyLength, void **data, long *dataLength);
long levelDBItemDelete(void *db, char *key, long keyLength);

#pragma mark - Iterator

void *levelDBIteratorNew(void *db);
void levelDBIteratorSeek(void *iter, char *key, long keyLength);
bool levelDBIteratorIsValid(void *iter);
void levelDBIteratorGetKey(void *iter, char **key, long *keyLength);
void levelDBIteratorGetValue(void *iter, void **data, long *dataLength);
void levelDBIteratorMoveForward(void *iter);
void levelDBIteratorMoveBackward(void *iter);
void levelDBIteratorMoveToFirst(void *iter);
void levelDBIteratorMoveToLast(void *iter);
void levelDBIteratorDelete(void *iter);
