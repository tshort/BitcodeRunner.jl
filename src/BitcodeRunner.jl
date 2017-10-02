
module BitcodeRunner

export bitcode_library

using LLVM

# Internal convertions used for arguments to `llvmcall`.
myconvert(T, x) = Base.cconvert(T, x)
myconvert(T::Type{Base.Ptr{V}}, x) where {V} = Base.unsafe_convert(T, x)

"""
    bitcode_library(bitcodefile, mod::Module = Module())

Reads in LLVM bitcode from the file named `bitcodefile`. Populates `mod` with Julia 
functions that map to every function defined in the bitcode file. This works by defining
Julia functions in `mod` that use `Base.llvmcall` to run the LLVM code. `mod` optionally
defaults to an anonymous Module.

Returns the Module with the loaded functions.
"""
function bitcode_library(bitcodefile, mod::Module = Module())
    ctx = LLVM.Context(convert(LLVM.API.LLVMContextRef, cglobal(:jl_LLVMContext, Void)))
    llvmmod = parse(LLVM.Module, read(bitcodefile), ctx)
    fns = functions(llvmmod)
    exs = Any[]
    for f in fns
            # @show attr = collect(function_attributes(f))
            # EnumAttribute("internal") in attr && continue
            # EnumAttribute("hidden") in attr && continue
            funname = Symbol(name(f))
        try
            rettypeX, argtypesX = params(f)
            rettype = maptype(rettypeX, mod)
            argtypes = maptype.(argtypesX, mod)
            n = length(argtypes)
            argnames = [Symbol(:x, i) for i in 1:n]
            # push!(exs, :(export $funname))
            # push!(exs, :($funname($(argnames...)) = Base.llvmcall($(LLVM.ref(f)), $rettype, Tuple{$(argtypes...)}, $([:($myconvert($(argtypes[i]), $(argnames[i]))) for i in 1:n]...))))
            # println(:($funname($(argnames...)) = Base.llvmcall($(LLVM.ref(f)), $rettype, Tuple{$(argtypes...)}, $([:($myconvert($(argtypes[i]), $(argnames[i]))) for i in 1:n]...))))
            eval(mod, :(export $funname; $funname($(argnames...)) = Base.llvmcall($(LLVM.ref(f)), $rettype, Tuple{$(argtypes...)}, $([:($myconvert($(argtypes[i]), $(argnames[i]))) for i in 1:n]...))))
            println("$funname")
        catch
            println("***FAILED: $funname")
        end
    end
    # open("t.out", "w") do io; print(io, Expr(:block, exs...)) end
    # eval(mod, Expr(:block, exs...))
    return mod
end

#
# Find the return type and the parameters of the LLVM function `f`.
# `returntype` is an LLVM type.
# `paramtypes` is a Vector of LLVM types, one for each argument.
#
function params(f)
    funtype = LLVM.API.LLVMGetElementType(LLVM.API.LLVMTypeOf(LLVM.ref(f)))
    returntype = LLVMType(LLVM.API.LLVMGetReturnType(funtype))
    nparams = LLVM.API.LLVMCountParamTypes(funtype)
    paramtypesraw = Vector{LLVM.API.LLVMTypeRef}(nparams)
    LLVM.API.LLVMGetParamTypes(funtype, paramtypesraw)
    paramtypes = LLVMType.(paramtypesraw)
    (returntype, paramtypes)
end

#
# Map the LLVM type (i32*) to its matching Julia type (Ptr{Int32}).
#
function maptype(x, m::Module)
    if isa(x, LLVM.VoidType)
        return Void
    end
    if isa(x, LLVM.IntegerType)
        w = width(x)
        return w == 1 ? Bool : eval(Symbol(:Int, w))
    end
    if isa(x, LLVM.FloatingPointType)
        return isa(x, LLVM.LLVMHalf)   ? Float16 :
               isa(x, LLVM.LLVMFloat)  ? Float32 :
               isa(x, LLVM.LLVMDouble) ? Float64 : nothing
    end
    if isa(x, LLVM.PointerType)
        return Ptr{maptype(eltype(x), m)}
    end
    if isa(x, LLVM.StructType)
        typename = Symbol(split(name(x), ".")[2])
        if !isdefined(m, typename)  # Create the type in Module `m` if not already there
            element_types = map(x -> maptype(x, m), elements(x))
            type_definition = :(struct $typename  end)
            type_definition.args[3].args = Any[:($(Symbol(:x,i)) :: $(element_types[i])) for i in 1:length(element_types)]
            eval(m, type_definition)
        end
        return getfield(m, typename)
    end
    if isa(x, LLVM.ArrayType)
        return NTuple{Int32(length(x)), maptype(eltype(x), m)}
    end
    error("Unknown or unsupported LLVM type: $x")
end

end # module
