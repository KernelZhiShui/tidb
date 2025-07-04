#!/bin/sh
#
# Copyright 2024 PingCAP, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu
DB="$TEST_NAME"

run_sql "CREATE DATABASE $DB;"

run_sql "CREATE TABLE $DB.usertable1 ( \
  YCSB_KEY varchar(64) NOT NULL, \
  FIELD0 varchar(1) DEFAULT NULL, \
  PRIMARY KEY (YCSB_KEY) \
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;"

run_sql "INSERT INTO $DB.usertable1 VALUES (\"a\", \"b\");"
run_sql "INSERT INTO $DB.usertable1 VALUES (\"aa\", \"b\");"

run_sql "CREATE TABLE $DB.usertable2 ( \
  YCSB_KEY varchar(64) NOT NULL, \
  FIELD0 varchar(1) DEFAULT NULL, \
  PRIMARY KEY (YCSB_KEY) \
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;"

run_sql "INSERT INTO $DB.usertable2 VALUES (\"c\", \"d\");"
# backup db
echo "backup start..."
run_br --pd $PD_ADDR backup full -s "local://$TEST_DIR/$DB"

run_sql "DROP DATABASE $DB;"

# restore db
echo "restore start..."
run_br restore db --db $DB -s "local://$TEST_DIR/$DB" --pd $PD_ADDR

table_count=$(run_sql "use $DB; show tables;" | grep "Tables_in" | wc -l)
if [ "$table_count" -ne "2" ];then
    echo "TEST: [$TEST_NAME] failed!"
    exit 1
fi

# restore db again
echo "restore start..."
LOG_OUTPUT=$(run_br restore db --db "$DB" -s "local://$TEST_DIR/$DB" --pd "$PD_ADDR" 2>&1 || true)

# Check if the log contains 'ErrTableAlreadyExisted'
if ! echo "$LOG_OUTPUT" | grep -q "ErrTablesAlreadyExisted"; then
    echo "Error: 'ErrTableAlreadyExisted' not found in logs."
    echo "Log output:"
    echo "$LOG_OUTPUT"
    exit 1 
else
    echo "restore failed as expect" 
fi

# restore with full -f option
echo "restore full start with -f option..."
LOG_OUTPUT=$(run_br restore full -f "$DB.*" -s "local://$TEST_DIR/$DB" --pd "$PD_ADDR" 2>&1 || true)

# Check if the log contains 'ErrTableAlreadyExisted'
if ! echo "$LOG_OUTPUT" | grep -q "ErrTablesAlreadyExisted"; then
    echo "Error: 'ErrTableAlreadyExisted' not found in logs."
    echo "Log output:"
    echo "$LOG_OUTPUT"
    exit 1
else
    echo "restore failed as expect" 
fi

# cleanup
echo "cleanup..."
run_sql "DROP DATABASE $DB;"

# restore with full -f option after cleanup
echo "restore full start with -f option after cleanup..."
run_br restore full -f "$DB.*" -s "local://$TEST_DIR/$DB" --pd "$PD_ADDR"

table_count=$(run_sql "use $DB; show tables;" | grep "Tables_in" | wc -l)
if [ "$table_count" -ne "2" ];then
    echo "TEST: [$TEST_NAME] failed!"
    exit 1
fi

run_sql "DROP DATABASE $DB;"