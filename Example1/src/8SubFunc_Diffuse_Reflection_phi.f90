!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      MODULE Method_Of_FLST_DiffuseReflec
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      USE constants
      USE RandUtils
      USE PhotonEmitterBB
      USE Photons_FlatSP
      USE MPI
      IMPLICIT NONE 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      CONTAINS  
!**************************************************************************************
    SUBROUTINE mimick_of_ph_Slab_BoundReflc( Total_Phot_Num, tau, T_bb, T_elec, &
                      CrossSec_filename, Spentrum_filename )
!************************************************************************************** 
    implicit none 
    real(mcp), intent(in) :: tau, T_bb, T_elec
    integer(kind = 8), intent(in) :: Total_Phot_Num
    character*80, intent(inout) :: CrossSec_filename, Spentrum_filename
    real(mcp) :: E, E_low, E_up  
    integer(kind = 8) :: Num_Photons 
    type(Photon_Emitter_BB) :: Emitter
    type(Photon_FlatSP) :: phot
    type(ScatPhoton_KN) :: sphot
    integer :: send_num, recv_num, send_tag, RECV_SOURCE, status(MPI_STATUS_SIZE), send_num2, recv_num2, &
               times_scat
    real(mcp) :: IQUV_Recv(1: 4, 0: 6, 1: Num_mu, 0: vL_sc_up)
    real(mcp) :: aa, bb, w1, x
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    integer :: i,j 
!--------------MPI---------------------------------------------------------------
    integer np, myid, ierr
    integer :: namelen
    character*(MPI_MAX_PROCESSOR_NAME) processor_name
    integer(kind = 8) :: mydutyPhot
!===========================================================================
    call MPI_INIT (ierr)
    call MPI_COMM_SIZE (MPI_COMM_WORLD, np, ierr)
    call MPI_COMM_RANK (MPI_COMM_WORLD, myid, ierr)
    call MPI_GET_PROCESSOR_NAME(processor_name, namelen, ierr)
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    write(*,*)'MyId Is:  ', np, myid, namelen
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
    if( myid == np-1 ) then
        mydutyphot = Total_Phot_Num / np + &
                   mod( Total_Phot_Num, np )
    else
        mydutyphot = Total_Phot_Num / np
    endif 

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CALL phot%Set_Initial_Values_For_Photon_Parameters( T_elec, T_bb, tau, Emitter, CrossSec_filename )
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    Num_Photons = 0   
    sphot%mu_estimat = phot%mu_estimat
 
      !call Set_xi_wi_all()
      w100(0) = one
      !aa = zero
      !bb = twopi
      !w1 = zero
      !do j = 0, 100 - 1
      !    x = ( ( bb - aa ) * x100(j) + ( bb + aa ) ) / two 
      !    w1 = w1 + w100(j) * dexp( - dsin(x**2) * dcos(x)**2 )
      !enddo 
      !write(*, *)'ffs=', w1 * pi 
      !stop
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    Do 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
        Num_Photons = Num_Photons + 1 
        phot%scatter_times = 0  
        times_scat = 0
    !write(*,*)'**********************************************************' 

        CALL phot%Generate_A_Photon( Emitter )    
        CALL phot%Determine_P_Of_Scatt_Site_And_Quantities_At_p()
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
        !CALL phot%FIRST_SCATTERING_OF_PHOT_ELCE( sphot )
        CALL phot%Photon_Electron_Scattering( sphot )
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        Scattering_loop: Do
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
            phot%scatter_times = phot%scatter_times + 1 
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
            !times_scat = times_scat + 1
            !CALL Set_InI_Conditions_For_Next_Scattering( phot, sphot )  
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
            CALL phot%Set_InI_Conditions_For_Next_Scattering( sphot )  
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
            !CALL Determine_Next_Scattering_Site( phot, sphot ) 
            !write(*,fmt="(' ', A8, 3ES15.5, I10)")'ssff222===', phot%Phot4k_CtrCF_ini(1), &
            !         mec2 * 10.D0, phot%w_ini, phot%scatter_times
            !write(*,fmt=*)'ssff222===', phot%Phot4k_CtrCF_ini(1), mec2 * 10.D0, &
                    !phot%w_ini, phot%scatter_times
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
            CALL phot%Determine_P_Of_Scatt_Site_And_Quantities_At_p() 
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
            !if( phot%Phot4k_CtrCF_ini(1) > mec2 * 1.D0)exit 
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
            if( phot%w_ini / phot%w_ini0 <= 1.D-30 .or. phot%scatter_times >= 10 )exit
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
            !if(phot%Vector_Stokes4_CF(1) < 1.D-30)exit
            !write(*,fmt=*)'ssff===', phot%w_ini / phot%w_ini0, phot%Vector_Stokes4_CF(1)
            !phot%scatter_times, times_scat, phot%w_ini, phot%w_ini0
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
            !if( phot%scatter_times >= 20 )exit  
            !if(   phot%Psi_I <= 1.D-1 )exit 
            !CALL phot%Photon_Electron_Scattering( sphot ) 
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            if( phot%InterSection_Cases == 1 .or. phot%InterSection_Cases == 3 )then
                CALL phot%Photon_Electron_Scattering( sphot )
                if( isnan( phot%Vector_Stokes4_CF(1) ) )then
                    write(*, *)'mmsf1=', phot%scatter_times, phot%Vector_Stokes4_CF, &
                     phot%z_tau, phot%z_max, phot%w_ini, phot%w_ini0, phot%w_ini / phot%w_ini0
                    stop
                endif 
            else if( phot%InterSection_Cases == 2 )then 
                CALL phot%IQUV_Reflection_From_BoundaryPlane_Phi( sphot ) 
                if( isnan( phot%Vector_Stokes4_CF(1) ) )then
                    write(*, *)'mmsf2=', phot%scatter_times, phot%Vector_Stokes4_CF
                    stop
                endif  
            endif
            !if( phot%z_tau < phot%z_max )then
            !    CALL phot%Photon_Electron_Scattering( sphot )
            !    if( isnan( phot%Vector_Stokes4_CF(1) ) )then
            !        write(*, *)'mmsf1=', phot%scatter_times, phot%Vector_Stokes4_CF, phot%z_tau, phot%z_max
            !        stop
            !    endif 
            !else
                !times_scat = times_scat + 1
                !if(times_scat == 2)exit
                !write(*,fmt=*)'ssff111===',  phot%scatter_times, phot%Phot4k_CtrCF_ini(1),  phot%w_ini
                !phot%z_tau = phot%z_max
                !phot%scatter_times = -1
                !CALL Photon_Reflection_From_BoundaryPlane( phot, sphot )
                !CALL phot%IQUV_Reflection_From_BoundaryPlane_Phi( sphot ) 
                !write(*,*)'ssff222===',  phot%scatter_times, sphot%Vector_Stokes4_CF_Scat
                !if( isnan( phot%Vector_Stokes4_CF(1) ) )then
                !    write(*, *)'mmsf2=', phot%scatter_times, phot%Vector_Stokes4_CF
                !    stop
                !endif
            !endif 
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        END DO Scattering_loop
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        !write(*,*)'************************************* *****',phot%scatter_times, phot%medium_case
  
       If( myid == np-1 )then
        If ( mod(Num_Photons, 50000)==0 ) then 
        write(unit = *, fmt = *)'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' 
        write(unit = *, fmt = "(' ', '~~~~~~  The', I12,' th Photons have been scattered for', &
             I5, A40)")Num_Photons, phot%scatter_times 
        write(unit = *, fmt = *)'~~~~~~  times and Escapted from the region !!!!!!!'          
        write(unit = *, fmt = "(' ', '~~~~~~  My ID is', I5, ',  And my Duty Photon Number is: ', I10)")&
                        myid, mydutyphot 
        write(unit = *, fmt = *)'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        endif
       endif
        If( Num_Photons > mydutyphot )EXIT
    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Enddo  
    120 format(' ', A35, 2I10)
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
      If ( myid /= np-1 ) then 
          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
          send_num  = ( vL_sc_up + 1 ) * 4 * 7 * Num_mu
          send_tag = 1  
          call MPI_SEND( phot%PolArrIQUV, send_num, MPI_DOUBLE_PRECISION, np-1, &
                        send_tag, MPI_COMM_WORLD, ierr)
          write(*, *)'Processor ', myid, ' has send PolarArrayI to Processor:', np-1
          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
      else 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
          if (np-2 >= 0) then
              do RECV_SOURCE = 0, np-2 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                  recv_num = ( vL_sc_up + 1 ) * 4 * 7 * Num_mu
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                  call MPI_RECV( IQUV_Recv, recv_num, MPI_DOUBLE_PRECISION, RECV_SOURCE, &
                                1, MPI_COMM_WORLD, status, ierr) 
                  write(*,*)'master Processor ', myid,' Receives I data from Processor:', RECV_SOURCE 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                  !phot%PolArrIQUVpmu11 = phot%PolArrIQUVpmu11 + IQUVmu11_Recv
                  !phot%PolArrIQUVpmu50 = phot%PolArrIQUVpmu50 + IQUVmu50_Recv
                  !phot%PolArrImu11 = phot%PolArrImu11 + Imu11_Recv
                  !phot%PolArrImu50 = phot%PolArrImu50 + Imu50_Recv
                  phot%PolArrIQUV = phot%PolArrIQUV + IQUV_Recv
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
              enddo
          endif  
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          write(*,*)'There are', phot%effect_number, 'of total', Total_Phot_Num, 'photons',&
                        'arrive at the plate of observer!!' 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          !do i = 0, Num_PolDeg
              !phot%PolarArrayd( i ) = DSQRT( phot%PolarArrayQ(i)**2 + phot%PolarArrayU(i)**2 &
              !                               ) / phot%PolarArrayI(i)
          !enddo 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
          !open(unit=10, file='./spectrum/IQUVpmu11.txt', status="replace")  
          !open(unit=11, file='./spectrum/IQUVpmu50.txt', status="replace")  
          !open(unit=12, file='./spectrum/I12345_mu11.txt', status="replace")  
          !open(unit=13, file='./spectrum/I12345_mu50.txt', status="replace") 
          !open(unit=9, file='./spectrum/IQUV_E3.txt', status="replace") 
          open(unit=13, file = Spentrum_filename, status="replace") 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          do i = 0, 6! Num_mu
              do j = 0, vL_sc_up
                  !write(unit = 10, fmt = 100)phot%PolArrIQUVpmu11(1: 5, j) 
                  !write(unit = 11, fmt = 100)phot%PolArrIQUVpmu50(1: 5, j) 
                  !write(unit = 12, fmt = 200)phot%PolArrImu11(0: 6, j) 
                  !write(unit = 13, fmt = 200)phot%PolArrImu50(0: 6, j) 
                  write(unit = 13, fmt = 200)phot%PolArrIQUV(1: 4, i, 1, j), phot%PolArrIQUV(1: 4, i, 2, j)
              enddo
          enddo
          100 FORMAT(' ', '    ', ES15.6, '    ', ES15.6, '    ', ES15.6, '    ', ES15.6, '    ', ES15.6)
          200 FORMAT(' ', ES15.6, '   ', ES15.6, '   ', ES15.6, '   ', ES15.6 ,'   ', &
                          ES15.6 ,'   ', ES15.6, '   ', ES15.6, '   ', ES15.6 )
          300 FORMAT(' ', '   ', ES15.6, '   ', ES15.6, '   ', ES15.6, '   ', ES15.6)
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          !close(unit=10)  
          !close(unit=11)  
          !close(unit=12) 
          !close(unit=13)
          close(unit=13)   
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      endif   
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    call MPI_FINALIZE ( ierr ) 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    END SUBROUTINE mimick_of_ph_Slab_BoundReflc
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    END MODULE Method_Of_FLST_DiffuseReflec
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   

    