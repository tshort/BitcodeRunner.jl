
#   Adapted from 
#   https://github.com/dabeaz/bitey/blob/master/test/test_M.py
#   
#   Copyright (C) 2012
#   David M. Beazley (Dabeaz LLC), http://www.dabeaz.com
#   BSD 3-clause "New" or "Revised" License


using Base.Test
using BitcodeRunner

M = bitcode_library("ctest.bc")

@test M.add_char(4,5) == Int8(9)
@test M.add_short(4,5) == Int16(9)
@test M.add_long(4,5) == Int32(9)
@test M.add_longlong(4,5) == Int64(9)

@test M.add_float(4,5) == 9f0
@test M.add_double(4,5) == 9.0

# Test passing Ref's and Arrays
a = Ref(Int16(2))
M.mutate_short(a)
@test a[] == Int16(4)
a = Ref(Int32(2))
M.mutate_long(a)
@test a[] == Int32(4)
a = Ref(Int64(2))
M.mutate_longlong(a)
@test a[] == Int64(4)
a = Ref(2f0)
M.mutate_float(a)
@test a[] == 4f0
a = Ref(2.0)
M.mutate_double(a)
@test a[] == 4.0
a = [2.0]
M.mutate_double(a)
@test a[1] == 4.0

# Array tests
@test M.arr_sum_int(collect(UInt32(1):UInt32(4))) == Int32(10)
@test M.arr_sum_double(collect(1.0:4.0)) == 10.0

# Struct test
p = Ref(M.Point(3, 4))
q = Ref(M.Point(6, 8))
@test M.distance(p, q) == 5.0
