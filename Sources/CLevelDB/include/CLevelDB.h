//
//  CLevelDB.h
//  CLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//

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

