export jInvPardisoSolver, getjInvPardisoSolver

"""
type jInvPardisoSolver

Fields:

	Ainv    - holds PardisoFactorization
	doClear - flag to clear factorization
	ooc     - flag for out-of-core option
	sym     - 0=unsymmetric, 1=symm. pos def, 2=general symmetric
	nFac    - number of factorizations performed
	facTime - cumulative time for factorizations
	nSolve  - number of solves
	solveTime - cumulative time for solves

Example: 

	Ainv = getjInvPardisoSolver()
"""
type jInvPardisoSolver<: AbstractSolver
	Ainv
	doClear::Int
	ooc::Int
	sym::Int
	nFac::Int
	facTime::Real
	nSolve::Int
	solveTime::Real
	N::Int
	nProcs::Int
end

# See if Pardiso is installed and include code for it.

	
if hasPardiso
		
	function getjInvPardisoSolver(Ainv=[],doClear=1,ooc=0,sym=11,nProcs=1)
		return jInvPardisoSolver(Ainv,doClear,ooc,sym,0,0.0,0,0.0,1,nProcs)
	end
	
	function solveLinearSystem!(A,B,X,param::jInvPardisoSolver,doTranspose=0)
		if param.doClear == 1
			clear!(param)
		end
		if param.Ainv==[]
			tic()
			param.Ainv = MKLPardisoSolver()
			set_nprocs!(param.Ainv, param.nProcs)
			param.N    = size(A,1)
			param,Apard = pardisoSetup(param,A)
			pardiso(param.Ainv,X,Apard,full(B))
			param.facTime+=toq()
			param.nFac+=1
		end
	   
		tic()
		# Since pardiso requires CSR matrices as input,
		# and Julia sparse matrices are CSC,
		# we need to tell pardiso to solve transposed
		# system when we want untransposed solve and
		#vice versa
		if (param.sym in [1, 3, 11, 13]) && (doTranspose == 0) 
		  set_iparm!(param.Ainv, 12, 2)
		else
		  set_iparm!(param.Ainv, 12, 0)
		end
		set_phase!(param.Ainv,33)
		pardiso(param.Ainv,X,A,full(B))
		param.solveTime+=toq()
		param.nSolve+=1
	
		return X, param		
	end # function solveLinearSystem MKLPardisoSolver
	
	function pardisoSetup(param::jInvPardisoSolver,A::SparseMatrixCSC)
			set_phase!(param.Ainv,12) #Perform analysis and numerical fac.
			set_matrixtype!(param.Ainv,param.sym) #Set matrix type
			pardisoinit(param.Ainv) #Initialize iparm
			set_iparm!(param.Ainv, 2, 3) #Use parallel metis ordering
			set_iparm!(param.Ainv, 27, 1) #Activate matrix checker
			if param.ooc != 0
			  set_iparm!(param.Ainv, 60, 2)
			end
			
			# Pardiso only needs upper triangular part of
			# symmetric matrices. We take lower triangular
			# part due to CSC vs CSR conflict.
			if param.sym in [2, 4, -2, -4, 6]
			  Apard = tril(A)
			else 
			  Apard = A
			end
			return param,Apard
	end
			
	import jInv.Utils.clear!
	function clear!(param::jInvPardisoSolver)
		if param.Ainv==[]
		        return
		else
			set_phase!(param.Ainv,-1)
			A = speye(2); x = ones(2);b = ones(2)
			pardiso(param.Ainv,x,A,b)
			param.Ainv = []
		end
	end
	
	function copySolver(Ainv::jInvPardisoSolver)
		return jInvPardisoSolver(Ainv.Ainv,Ainv.doClear,
		                         Ainv.ooc,Ainv.sym,0,0.0,0
		                         ,0.0,1,Ainv.nProcs);
	end
		
end
