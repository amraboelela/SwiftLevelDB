//
// Copyright (c) 2016 Amr Aboelela <amraboelela@gmail.com>
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fcntl.h>
#include "db/db_impl.h"
#include "leveldb/env.h"

#pragma mark - Static functions

static leveldb::ReadOptions readOptions;
static leveldb::WriteOptions writeOptions;

static char *CopyString(const std::string& str) {
    char *result = reinterpret_cast<char*>(malloc(sizeof(char) * str.size()));
    memcpy(result, str.data(), sizeof(char) * str.size());
    return result;
}

#pragma mark - Database

extern "C" void *levelDBOpen(char *path) {
    
    leveldb::Options options;
    options.create_if_missing = true;
    options.paranoid_checks = false;
    options.error_if_exists = false;
#if defined(__linux)
    //printf("levelDBOpen in Linux\n");
#else
    //printf("levelDBOpen in iOS\n");
    options.compression = leveldb::kSnappyCompression;
#endif
    
    readOptions.fill_cache = true;
    writeOptions.sync = false;
    leveldb::DB *db;
    leveldb::Status status = leveldb::DB::Open(options, path, &db);
    
    if (!status.ok()) {
        printf("Problem creating LevelDB database: %s\n", status.ToString().c_str());
        char *lockStr = "/LOCK";
        char *lockPath;
        if ((lockPath = (char *)malloc(strlen(path)+strlen(lockStr)+1)) != NULL) {
            lockPath[0] = '\0';   // ensures the memory is an empty string
            strcat(lockPath,path);
            strcat(lockPath,lockStr);
        } else {
            printf("malloc failed!\n");
            // exit?
        }
        long fd = open(lockPath, O_RDWR | O_CREAT, 0644);
        if (LockOrUnlock(fd, false) != -1) {
            printf("Was able to unlock the databse\n");
        } else {
            printf("Couldn't unlock the databse\n");
            return NULL;
        }
        status = RepairDB(path, options);
        if (status.ok()) {
            printf("Was able to repair databse\n");
        } else {
            printf("Couldn't repair databse\n");
            return NULL;
        }
        status = leveldb::DB::Open(options, path, &db);
        if (!status.ok()) {
            printf("Problem creating LevelDB database: %s\n", status.ToString().c_str());
            return NULL;
        }
    }
    return db;
}

extern "C" void levelDBDelete(void *db) {
    delete db;
}

#pragma mark - Item

extern "C" long levelDBItemPut(void *db, char *key, long keyLength, void *data, long dataLength) {
    
    leveldb::Slice k = leveldb::Slice(key, keyLength);
    leveldb::Slice v = leveldb::Slice((char *)data, dataLength);
    
    leveldb::Status status = ((leveldb::DB *)db)->Put(writeOptions, k, v);
    
    if (status.ok()) {
        return 0;
    } else {
        return -1;
    }
}

extern "C" long levelDBItemGet(void *db, char *key, long keyLength, void **data, long *dataLength) {
    leveldb::Slice k = leveldb::Slice(key, keyLength);
    leveldb::ReadOptions *readOptionsPtr = &readOptions;
    std::string v_string;
    leveldb::Status status = ((leveldb::DB *)db)->Get(*readOptionsPtr, k, &v_string);
    if (status.ok()) {
        *data = CopyString(v_string);
        *dataLength = v_string.size();
        return 0;
    } else {
        return -1;
    }
}

extern "C" long levelDBItemDelete(void *db, char *key, long keyLength) {
    leveldb::Slice k = leveldb::Slice(key, keyLength);
    leveldb::Status status = ((leveldb::DB *)db)->Delete(writeOptions, k);
    if (status.ok()) {
        return 0;
    } else {
        return -1;
    }
}

#pragma mark - Iterator

extern "C" void *levelDBIteratorNew(void *db) {
    leveldb::ReadOptions *readOptionsPtr = &readOptions;
    return ((leveldb::DB *)db)->NewIterator(*readOptionsPtr);
}

extern "C" void levelDBIteratorSeek(void *iter, char *key, long keyLength) {
    ((leveldb::Iterator *)iter)->Seek(leveldb::Slice(key, keyLength));
}

extern "C" bool levelDBIteratorIsValid(void *iter) {
    return ((leveldb::Iterator *)iter)->Valid();
}

extern "C" void levelDBIteratorGetKey(void *iter, char **key, long *keyLength) {
    leveldb::Slice lkey = ((leveldb::Iterator *)iter)->key();
    *key = (char *)lkey.data();
    *keyLength = lkey.size();
}

extern "C" void levelDBIteratorGetValue(void *iter, void **data, long *dataLength) {
    leveldb::Slice lvalue = ((leveldb::Iterator *)iter)->value();
    *data = (void *)lvalue.data();
    *dataLength = lvalue.size();
}

extern "C" void levelDBIteratorMoveForward(void *iter) {
    ((leveldb::Iterator *)iter)->Next();
}

extern "C" void levelDBIteratorMoveBackward(void *iter) {
    ((leveldb::Iterator *)iter)->Prev();
}

extern "C" void levelDBIteratorMoveToFirst(void *iter) {
    ((leveldb::Iterator *)iter)->SeekToFirst();
}

extern "C" void levelDBIteratorMoveToLast(void *iter) {
    ((leveldb::Iterator *)iter)->SeekToLast();
}

extern "C" void levelDBIteratorDelete(void *iter) {
    delete iter;
}
