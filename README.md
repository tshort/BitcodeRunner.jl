# BitCodeRunner

The main purpose of this package is to load an LLVM bitcode (.bc) file and make the functions available in a module for immediate use. 

This uses [LLVM.jl](https://github.com/maleadt/LLVM.jl) and follows the approach in the Python package [bitey](https://github.com/dabeaz/bitey) by David Beazley and also ideas by @staticfloat at [llvmjltomfoolery](https://github.com/staticfloat/llvmjltomfoolery). 
The first step is to compile code to LLVM bitcode. 
In the `test` directory, one can do the following in a shell script to create a `ctest.bc` bitcode file:

```
clang -emit-llvm -c ctest.c
```
From there, it's easy on the Julia side:

```julia
julia> using BitcodeRunner

julia> M = bitcode_library("ctest.bc")
anonymous

julia> M.add_long(1, 6)
7

julia> a = collect(1.0:4.0)
4-element Array{Float64,1}:
 1.0
 2.0
 3.0
 4.0

julia> M.arr_sum_double(a)
10.0

julia> p = Ref(M.Point(3, 4))
Base.RefValue{anonymous.Point}(anonymous.Point(3.0, 4.0))

julia> q = Ref(M.Point(6, 8))
Base.RefValue{anonymous.Point}(anonymous.Point(6.0, 8.0))

julia> M.distance(p, q)
5.0
```

You can also load in the function definitions by supplying a Module, like `bitcode_library("ctest.bc", MyModule)`.

### My Use Case

My main use case is to use this package to help in trying to compile Julia code to JavaScript and WebAssembly. 
[Emscripten](http://emscripten.org/) can compile C and C++ code to bitcode files and then link those and emit JavaScript and/or WebAssembly. Julia can also emit bitcode files. See [here](https://github.com/tshort/jl2js-dock) for a promising start using Docker to help keep software versions together. 

The biggest [stumbling block](https://github.com/tshort/jl2js-dock/issues/1) I've found is code that uses `ccall` to call out to dynamic libraries. 
Emscripten is a static compiler. We somehow need to convert those `ccall`'s to `llvmcall`'s. 
That's not easy because Julia's JIT expects "fully formed" bitcode. 
You can't leave undeclared functions. 
My hope is that with this package, I can replace `ccall`'s with calls to functions preloaded by `bitcode_library`.
In effect, Julia will be doing the linking. 


### Caveats

* LLVM.jl is still a challenge to get installed. You need to compile Julia from source. Until LLVM is easier to install, I don't plan to register this package.

* This hasn't been tested on large libraries, yet.

* For types defined in the bitcode file (like `M.Point` above), the field names are not included in the file, so when `bitcode_library` creates the struct for this, dummy field names of `x1`, `x2`, ... are used. You can specify field names if you pre-define a Module and include a definition for the struct.
