export Stieltjes,Cauchy


#############
# Cauchy implements the Cauchy operator corresponding to evaluating the Cauchy transform
#
#       C f(z) := 1/(2πi)\int_Γ f(t)/(t-z) dt
#
# It is given in terms of the Stieltjes operator
#
#       S f(z) := \int_Γ f(t)/(z-t) dt = -2πi*C f(z)
#
# note that the domain of domainspace must be different than the domain of rangespace
#
# The notion of C^± for the left/right limits of the Cauchy operator
# with the domains matching is represented
# using the Hilbert operator and the formulae
#
#    C^+  -  C^- = I
#    C^+  +  C^- = -im*H
#
#   Or for the Stieltjes operator
#
#    S^+ - S^- = -2πi*I
#    S^+ + S^- = -2π*H
#
############

immutable Stieltjes{D<:FunctionSpace,R<:FunctionSpace} <: BandedOperator{Complex{Float64}}
    data::BandedMatrix{Complex{Float64}}
    domainspace::D
    rangespace::R
end


    ## Stieltjes(s,d)


Cauchy(s::Bool,d)=(s?0.5:-0.5)*I +(-0.5im)*Hilbert(d)
Cauchy(s::Int,d)=Cauchy(s==1,d)
Cauchy(s::Union(Int,Bool))=Cauchy(s,UnsetSpace())
Stieltjes(ds::PeriodicDomain,rs::PeriodicDomain)=Stieltjes(Laurent(ds),Laurent(rs))
Cauchy(ds,rs)=(1/(-2π*im))*Stieltjes(ds,rs)

domainspace(C::Stieltjes)=C.domainspace
rangespace(C::Stieltjes)=C.rangespace
bandinds(C::Stieltjes)=bandinds(C.data)


## Stieltjes


function Stieltjes(ds::JacobiWeight{Ultraspherical{1}},rs::FunctionSpace)
    @assert ds.α==ds.β==0.5

    x=Fun(identity,rs)
    y=intervaloffcircle(true,tocanonical(ds,x))

    ret=Array(typeof(y),300)
    ret[1]=y
    n=1
    l=length(y)-1
    u=0

    while norm(ret[n].coefficients)>100eps()
        n+=1
        if n > length(ret)
            # double preallocated ret
            resize!(ret,2length(ret))
        end
        ret[n]=chop!(y*ret[n-1],100eps())  #will be length 2n-1
        u+=1   # upper bandwidth
        l=max(l,length(ret[n])-n)
    end

    M=bazeros(Complex{Float64},n+l,n,l,u)
    for k=1:n,j=1:length(ret[k])
        M[j,k]=π*ret[k].coefficients[j]
    end
    Stieltjes(M,ds,rs)
end


function Stieltjes(ds::JacobiWeight{ChebyshevDirichlet{1,1}},rs::FunctionSpace)
    @assert ds.α==ds.β==-0.5

    z=Fun(identity,rs)
    x=tocanonical(ds,z)
    y=intervaloffcircle(true,x)

    ret=Array(typeof(y),300)
    ret[1]=1/sqrtx2(x)
    ret[2]=x*ret[1]-1
    ret[3]=-2y

    n=3
    l=max(length(ret[1])-1,length(ret[2])-1,length(ret[3])-3)
    u=2

    while norm(ret[n].coefficients)>100eps()
        n+=1
        if n > length(ret)
            # double preallocated ret
            resize!(ret,2length(ret))
        end
        ret[n]=chop!(y*ret[n-1],100eps())  #will be length 2n-1
        u+=1   # upper bandwidth
        l=max(l,length(ret[n])-n)
    end

    M=bazeros(Complex{Float64},n+l,n,l,u)
    for k=1:n,j=1:length(ret[k])
        M[j,k]=π*ret[k].coefficients[j]
    end
    Stieltjes(M,ds,rs)
end


function Stieltjes(DS::Laurent,RS::Laurent)
    ds=domain(DS);rs=domain(RS)
    @assert isa(ds,Circle)
    @assert isa(rs,Circle)

    c2=rs.center;c1=ds.center
    r2=rs.radius;r1=ds.radius

    if r1>r2&&abs(c1-c2)<r1  # we are inside the circle, use Taylor series
        M=interior_cauchy(ds,rs)
    elseif r1<r2&&abs(c1-c2)<r2 # we surround the domain, use Hardy{False} series
        M=exterior_cauchy(ds,rs)
    else
        M=disjoint_cauchy(ds,rs)
    end

    Stieltjes(-2π*im*M,DS,RS)
end

addentries!(C::Stieltjes,A,kr)=addentries!(C.data,A,kr)




## Special cases

function exterior_cauchy(b::Circle,a::Circle)
    c=b.center
    r=b.radius

    S=Fun([0.0,0,1],a)  # Shift to use bandedness
    ret=Array(Fun{Laurent,Complex{Float64}},300)
    ret[1]=Fun(z->(r/(z-c)),a)
    n=1
    m=length(ret[1])-2
    f1=ret[1]*S
    while norm(ret[n].coefficients)>100eps()
        n+=1
        if n > length(ret)
            resize!(ret,2length(ret))
        end
        ret[n]=chop!(f1*ret[n-1],100eps())
        m=max(m,length(ret[n])-2)
    end

    M=bazeros(Complex{Float64},2n,2n,m,0)
    #j+2k-2≤2n
    #j≤2(n-k)+2
    for k=1:n,j=2:2:min(length(ret[k].coefficients),2(n-k)+2)
        M[j+2k-2,2k]=-ret[k].coefficients[j]
    end
    M
end

function interior_cauchy(a::Circle,b::Circle)
    c=a.center
    r=a.radius


    z=Fun(z->(z-c)/r,b)

    ret=Array(Fun{Laurent,Complex{Float64}},300)
    ret[1]=ones(b)
    n=1
    m=0

    while norm(ret[n].coefficients)>100eps()
        n+=1
        if n > length(ret)
            # double preallocated ret
            resize!(ret,2length(ret))
        end
        ret[n]=z*ret[n-1]  #will be length 2n-1


        # find bandwidth by checking how many coefficients are zero
        # we jump over negative coefficients
        for j=1:2:2n-1
            if norm(ret[n].coefficients[j])>100eps()
                m=max(m,2n-j-1)
                break
            end
        end
    end

    M=bazeros(Complex{Float64},2n-1,2n-1,0,m)
    for k=1:n,j=max(1,2k-1-m):2:2k-1
        M[j,2k-1]=ret[k].coefficients[j]
    end

    M
end

function disjoint_cauchy(a::Circle,b::Circle)
    c=a.center
    r=a.radius

    f=Fun(z->r/(z-c),b)

        ret=Array(Fun{Laurent,Complex{Float64}},300)
    ret[1]=f
    n=1

    l=length(f)-2   #lower bandwidth
    u=1             #upper bandwidth

    while norm(ret[n].coefficients)>100eps()
        n+=1
        if n > length(ret)
            # double preallocated ret
            resize!(ret,2length(ret))
        end
    ret[n]=chop!(f*ret[n-1],100eps())  #will be length 2n-1
    u=max(u,length(ret[n])-2n)   # upper bandwidth

        # find bandwidth by checking how many coefficients are zero
        # we jump over negative coefficients
        for j=1:2:length(ret[n])
            if norm(ret[n].coefficients[j])>100eps()
                l=max(l,2n-j)
                break
            end
        end
    end

    M=bazeros(Complex{Float64},2n-1,2n,l,u)
    for k=1:n,j=max(1,2k-u):2:min(length(ret[k]),2n-1)
            M[j,2k]=-ret[k].coefficients[j]
    end
    M
end

