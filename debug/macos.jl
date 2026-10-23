# Diagnose the macOS-only mismatch in GeoInterface.testfeaturecollection on UScounties.fgb
using FlatGeobuf, GeoInterface, InteractiveUtils
const GI = GeoInterface
versioninfo()
println("FlatBuffers: ", pkgdir(FlatGeobuf.FlatBuffers))
fn = joinpath(@__DIR__, "..", "test", "UScounties.fgb")
fgb = FlatGeobuf.read(fn)
seek(fgb.io, fgb.offset)
const buf = read(fgb.io, read(fgb.io, UInt32))
const ref = FlatGeobuf.Feature(copy(buf))
const refcoords = GI.coordinates(ref)
println("feature 1: $(length(buf)) bytes, $(GI.npoint(ref.geometry)) points")

# First position where two nested coordinate arrays differ
function firstdiff(a, b, path=Int[])
    a == b && return nothing
    (a isa AbstractVector && b isa AbstractVector && eltype(a) <: AbstractVector) || return (path, a, b)
    length(a) == length(b) || return (path, "length $(length(a))", "length $(length(b))")
    for i in eachindex(a)
        d = firstdiff(a[i], b[i], [path; i])
        isnothing(d) || return d
    end
end

# 1. Parse the same bytes many times
nbad = 0
for k in 1:5000
    c = GI.coordinates(FlatGeobuf.Feature(buf))
    if c != refcoords
        global nbad += 1
        nbad <= 3 && println("  parse $k differs: ", firstdiff(c, refcoords))
    end
end
println("repeated parse: $nbad of 5000 differ")

# 2. The failing assertion, comparing both sides with the reference
for k in 1:3
    fgb = FlatGeobuf.read(fn)
    a = GI.coordinates(fgb)
    b = GI.coordinates.(GI.getfeature(fgb))
    bada = findall(!=(refcoords), a)
    badb = findall(!=(refcoords), b)
    println("assertion run $k: equal=$(a == b), lhs differs in $(length(bada)) features, rhs in $(length(badb))")
    isempty(bada) || println("  lhs feature $(first(bada)): ", firstdiff(a[first(bada)], refcoords))
    isempty(badb) || println("  rhs feature $(first(badb)): ", firstdiff(b[first(badb)], refcoords))
    a = b = nothing
    GC.gc()
end
