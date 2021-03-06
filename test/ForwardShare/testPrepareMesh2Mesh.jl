using jInv.ForwardShare
using jInv.Mesh
using Base.Test

type TestProb <: ForwardProbType
	Mesh::AbstractMesh 	
end


Minv = getRegularMesh([0 1 0 2 0 3],[12 14 16])
Mfor = getRegularMesh([0 1 0 2 0 3],[6 7 8])
pFor = TestProb(Mfor)
pFors = Array{RemoteRef{Channel{Any}}}(2)
pFors[1] = @spawn identity(pFor)
pFors[2] = @spawn identity(pFor)


# prepare single mesh2mesh
M2Mc = prepareMesh2Mesh(pFor,Minv,true) # compact
M2Mf = prepareMesh2Mesh(pFor,Minv,false) # not compact
M2Mrc = prepareMesh2Mesh(pFors,Minv,true) # compact
M2Mrf = prepareMesh2Mesh(pFors,Minv,false) # compact

println("compare remote versions with local ones")
@test all(fetch(M2Mrc[1]).==M2Mc)
@test all(fetch(M2Mrf[1]).==M2Mf)

println("test interpGlobal2Local")
x   = randn(Minv.nc)
xf1 = interpGlobalToLocal(x,M2Mc)
xf2 = interpGlobalToLocal(x,M2Mf)
@test norm(xf1-xf2)/norm(xf2) < 1e-12

println("test interpLocal2Global")
x = randn(Mfor.nc)
xf1 = interpLocalToGlobal(x,M2Mc)
xf2 = interpLocalToGlobal(x,M2Mf)
@test norm(xf1-xf2)/norm(xf2) < 1e-12



