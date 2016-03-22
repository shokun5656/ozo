module mod_common_subrs
  implicit none
contains

!-------------------------------------------------------------------------------
! This module contains some general subroutines which can be used both 
! generalized omega equation and Zwack-okossi equation. 
!-------------------------------------------------------------------------------

  subroutine nondivergentWind(zeta,dx,dy,uPsi,vPsi)
!   This subroutine calculates nondivergent wind components (uPsi,vPsi) by using
!   streamfunction (psi).
!    use mod_poisson
    implicit none
 
    real, dimension(:,:,:),intent(in) :: zeta
    real,                  intent(in) :: dx,dy
    real, dimension(:,:,:),intent(inout) :: uPsi,vPsi 

    real, dimension(:,:,:),allocatable :: psi,dpsidx,dpsidy
    double precision, dimension ( : ), allocatable ::  bd_0
    integer :: nlon,nlat,nlev,k
    nlon=size(zeta,1); nlat=size(zeta,2); nlev=size(zeta,3)
    allocate(psi(nlon,nlat,nlev))
    allocate(dpsidx(nlon,nlat,nlev),dpsidy(nlon,nlat,nlev))
    allocate(bd_0(nlon+1))

!   Calculating streamfunction from vorticity by using inverse laplacian

    bd_0=0.0e0
    do k=1,nlev
!       call poisson_solver_2D(zeta(:,:,k),"PPDD",.false.,"DFT",dx,dy,&
!            psi(:,:,k),bd_0,bd_0)
    enddo

!   X- and y-derivatives of streamfunction
    call xder_cart(psi,dx,dpsidx)
    call yder_cart(psi,dy,dpsidy)

!   Wind components
    uPsi=-dpsidy
    vPsi=dpsidx

  end subroutine nondivergentWind

  subroutine irrotationalWind(u,v,dx,dy,uKhi,vKhi)
!   This subroutine calculates irrotational wind components (uKhi,vKhi) from
!   velocity potential. 
!    use mod_poisson
    implicit none

    real,dimension(:,:,:),intent(in) :: u,v
    real,                 intent(in) :: dx,dy 
    real,dimension(:,:,:),intent(out) :: uKhi,vKhi

    integer :: nlon,nlat,nlev,k
    double precision, dimension ( : ), allocatable ::  bd_0
    real,dimension(:,:,:),allocatable :: dudx,dvdy,khi,dkhidx,dkhidy

    nlon=size(u,1); nlat=size(u,2); nlev=size(u,3)
    allocate(dudx(nlon,nlat,nlev),dvdy(nlon,nlat,nlev))
    allocate(khi(nlon,nlat,nlev))
    allocate(dkhidx(nlon,nlat,nlev),dkhidy(nlon,nlat,nlev))
    allocate(bd_0(nlon+1))

!   Calculate the divergence of wind
    call xder_cart(u,dx,dudx)
    call yder_cart(v,dy,dvdy)

!   Velocity potential is equal to inverse laplacian of divergence

    bd_0=0.0e0
    do k=1,nlev
!       call poisson_solver_2D(dudx(:,:,k)+dvdy(:,:,k),"PPDD",.false.,"DFT",&
!            dx,dy,khi(:,:,k),bd_0,bd_0)
    enddo

!   Derivatives of velocity potential
    call xder_cart(khi,dx,dkhidx)
    call yder_cart(khi,dy,dkhidy)

!   Wind components are equal to derivatives
    uKhi=dkhidx
    vKhi=dkhidy
              
  end subroutine irrotationalWind

  subroutine curl_cart(u,v,dx,dy,zeta)
!   Relative vorticity in cartesian coordinates.
!   The domain is assumed to be periodic in east-west-direction
!   At the northern and southern boundaries, one-sided y derivatives are used.
    implicit none
    real,dimension(:,:,:),intent(in) :: u,v
    real,                 intent(in) :: dx,dy
    real,dimension(:,:,:),intent(inout) :: zeta

    integer :: i,i1,i2,j,k,nlon,nlat,nlev
    real :: dudy,dvdx
    nlon=size(u,1); nlat=size(u,2); nlev=size(u,3)

    do k=1,nlev
       do i=1,nlon
          i1=i-1
          i2=i+1
          if(i1.lt.1)i1=i1+nlon
          if(i2.gt.nlon)i2=i2-nlon
          do j=1,nlat
             if(j.gt.1.and.j.lt.nlat)then
                dudy=(u(i,j+1,k)-u(i,j-1,k))/(2*dy)
             else
                if(j.eq.1)dudy=(u(i,j+1,k)-u(i,j,k))/dy
                if(j.eq.nlat)dudy=(u(i,j,k)-u(i,j-1,k))/dy
             endif
             dvdx=(v(i2,j,k)-v(i1,j,k))/(2*dx)
             zeta(i,j,k)=dvdx-dudy
          enddo
       enddo
    enddo

  end subroutine curl_cart

  subroutine pder(f,dp,dfdp)
!   Estimation of pressure derivatives.
!   One-sided derivatives are used at top and bottom levels 
    implicit none

    real,dimension(:,:,:),intent(in) :: f
    real,                 intent(in) :: dp
    real,dimension(:,:,:),intent(inout) :: dfdp
    
    integer :: nlon,nlat,nlev
    nlon=size(f,1); nlat=size(f,2); nlev=size(f,3)

    dfdp(:,:,2:nlev-1)=f(:,:,3:nlev)-f(:,:,1:nlev-2)
    dfdp(:,:,2:nlev-1)=dfdp(:,:,2:nlev-1)/(2.*dp)
    
    dfdp(:,:,1)=(f(:,:,2)-f(:,:,1))/dp
    dfdp(:,:,nlev)=(f(:,:,nlev)-f(:,:,nlev-1))/dp

!    do i=1,nlon
!       do j=1,nlat
!          do k=2,nlev-1
!             dfdp(i,j,k)=(f(i,j,k+1)-f(i,j,k-1))/(2.*dp)
!          enddo
!          dfdp(i,j,1)=(f(i,j,2)-f(i,j,1))/dp
!          dfdp(i,j,nlev)=(f(i,j,nlev)-f(i,j,nlev-1))/dp
!       enddo
!    enddo

  end subroutine pder

  subroutine xder_cart(f,dx,dfdx)
!   Calculation of x derivatives. Periodic domain in x assumed
    implicit none

    real,dimension(:,:,:),intent(in) :: f
    real,                 intent(in) :: dx
    real,dimension(:,:,:),intent(inout) :: dfdx

    integer :: i,j,k,nlon,nlat,nlev,i1,i2
    nlon=size(f,1); nlat=size(f,2); nlev=size(f,3)

    do k=1,nlev
       do i=1,nlon
          i1=max(i-1,1)
          i2=min(i+1,nlon)
          if(i1.eq.i)i1=nlon
          if(i2.eq.i)i2=1
          do j=1,nlat
             dfdx(i,j,k)=(f(i2,j,k)-f(i1,j,k))/(2.*dx)
          enddo
       enddo
    enddo
    
  end subroutine xder_cart

  subroutine yder_cart(f,dy,dfdy)                          
!   Calculation of y derivatives
!   One-sided estimates are used at the southern and northern boundaries
    implicit none

    real,dimension(:,:,:),intent(in) :: f
    real,                 intent(in) :: dy
    real,dimension(:,:,:),intent(inout) :: dfdy

    integer :: i,j,k,nlon,nlat,nlev
    nlon=size(f,1); nlat=size(f,2); nlev=size(f,3)

    do k=1,nlev
       do i=1,nlon
          do j=2,nlat-1
             dfdy(i,j,k)=(f(i,j+1,k)-f(i,j-1,k))/(2*dy)
          enddo
          dfdy(i,1,k)=(f(i,2,k)-f(i,1,k))/dy
          dfdy(i,nlat,k)=(f(i,nlat,k)-f(i,nlat-1,k))/dy
       enddo
    enddo

  end subroutine yder_cart
  
  subroutine advect_cart(u,v,f,dx,dy,adv)
!   Computing u*dfdx + v*dfdy in cartesian coordinates
    implicit none

    real,dimension(:,:,:),intent(in) :: u,v,f
    real,                 intent(in) :: dx,dy
    real,dimension(:,:,:),intent(inout) :: adv

    real,dimension(:,:,:),allocatable :: dfdx,dfdy
    integer :: nlon,nlat,nlev
    nlon=size(u,1); nlat=size(u,2); nlev=size(u,3)
    allocate(dfdx(nlon,nlat,nlev),dfdy(nlon,nlat,nlev))
    
    call xder_cart(f,dx,dfdx)
    call yder_cart(f,dy,dfdy)
    
    adv=u*dfdx+v*dfdy   
  
  end subroutine advect_cart

  subroutine define_sigma(t,lev,dlev,sigma)
!   Calculatig sigma stability parameter in isobaric coordinates
    use mod_const
    implicit none
   
    real,dimension(:,:,:),intent(in) :: t
    real,dimension(:),    intent(in) :: lev
    real,                 intent(in) :: dlev
    real,dimension(:,:,:),intent(inout) :: sigma

    integer :: k,nlon,nlat,nlev
    real,dimension(:,:,:),allocatable :: apu1,apu2

    nlon=size(t,1); nlat=size(t,2); nlev=size(t,3)
    allocate(apu1(nlon,nlat,nlev),apu2(nlon,nlat,nlev))

    do k=1,nlev
       apu1(:,:,k)=log(t(:,:,k))-(r/cp)*log(lev(k)/1e5)
    enddo
    call pder(apu1,dlev,apu2)
    do k=1,nlev
       sigma(:,:,k)=-R*t(:,:,k)/lev(k)*apu2(:,:,k)
    enddo
    
  end subroutine define_sigma

  subroutine define_sp(sigma,lev,sp)
!   Calculating Sp stability parameter
    use mod_const
    implicit none

    real,dimension(:,:,:),intent(in) :: sigma
    real,dimension(:),intent(in) :: lev
    real,dimension(:,:,:),intent(inout) :: sp
 
    integer :: nlon,nlat,nlev,k
    nlon=size(sigma,1); nlat=size(sigma,2); nlev=size(sigma,3)

    do k=1,nlev
       sp(:,:,k)=sigma(:,:,k)*lev(k)/r
    enddo
    
  end subroutine define_sp

  subroutine laplace_cart(f,lapl,dx,dy)
!     Laplace operator in cartesian coordinates
!
!     The domain is assumed to be periodic in east-west-direction
!     ** At the northern and southern boundaries, second y derivative is assumed to be zero
    implicit none

    real,dimension(:,:,:),intent(in) :: f
    real,                 intent(in) :: dx,dy
    real,dimension(:,:,:),intent(out) :: lapl
    integer :: nlon,nlat,nlev

    nlon=size(f,1)
    nlat=size(f,2)
    nlev=size(f,3)

 ! x-direction
    lapl ( 2 : nlon - 1, :, : ) = f( 1: nlon - 2, :, : ) + f ( 3: nlon, :, : ) &
         - 2 * f( 2 : nlon - 1, :, : )
    lapl ( 1, :, : )    = f( nlon, :, : ) + f ( 2, :, : ) &
         - 2 * f( 1, :, : )
    lapl ( nlon, :, : ) = f( nlon - 1, :, : ) + f ( 1, :, : ) &
         - 2 * f( nlon, :, : )
    lapl = lapl / ( dx * dx )

    ! y-directon
    lapl ( :, 2 : nlat -1, : ) = lapl ( :, 2 : nlat -1, : ) &
         + ( f ( :, 1 : nlat -2, : ) + f ( :, 3 : nlat, :) &
         - 2 * f( :, 2 : nlat -1, : ) ) / ( dy * dy )

  end subroutine laplace_cart
  
end module mod_common_subrs