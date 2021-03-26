!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      MODULE Method_Of_FLST_DiffuseReflec
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      USE constants
      USE RandUtils
      USE PhotonEmitterBB
      USE Photons_FlatSP 
      IMPLICIT NONE 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      CONTAINS  
!**************************************************************************************
    SUBROUTINE mimick_of_ph_Slab_BoundReflc( Total_Phot_Num, tau, T_bb, T_elec, &
               E1_scat, E2_scat, y_obs1, y_obs2, mu_esti, sin_esti, Num_mu_esti, &
               TerminateTime, Terminate_Tolerence, CrossSec_filename, Savefilename )
!************************************************************************************** 
    implicit none 
    real(mcp), intent(in) :: tau, T_bb, T_elec, E1_scat, E2_scat, y_obs1, &
                      y_obs2, mu_esti(1: 4), sin_esti(1: 4), Terminate_Tolerence
    integer(kind = 8), intent(in) :: Total_Phot_Num
    integer, intent(in) :: Num_mu_esti, TerminateTime
    character*80, intent(inout) :: CrossSec_filename, Savefilename
    real(mcp) :: E, E_low, E_up  
    integer(kind = 8) :: Num_Photons 
    type(Photon_Emitter_BB) :: Emitter
    type(Photon_FlatSP) :: phot
    type(ScatPhoton_KN) :: sphot
    integer :: send_num, recv_num, send_tag, RECV_SOURCE, &
              status(MPI_STATUS_SIZE), send_num2, recv_num2
    real(mcp) :: IQUV_Recv(1: 4, 0: 6, 1: Num_mu, 0: vL_sc_up)
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
    phot%myid = myid
    phot%num_np = np
 
    call InitRandom( myid ) 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
    if( myid == np-1 ) then
        mydutyphot = Total_Phot_Num / np + &
                   mod( Total_Phot_Num, np )
    else
        mydutyphot = Total_Phot_Num / np
    endif 
 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    CALL phot%Set_Initial_Values_For_Photon_Parameters( T_elec, T_bb, &
                tau, E1_scat, E2_scat, y_obs1, y_obs2, mu_esti, sin_esti, &
                Num_mu_esti, CrossSec_filename )
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    Num_Photons = 0
    !sphot%mu_estimat = phot%mu_estimat
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    Do
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
        Num_Photons = Num_Photons + 1 
        phot%scatter_times = 0
        CALL phot%Generate_A_Photon()   
        CALL phot%Determine_P_Of_Scatt_Site_And_Quantities_At_p()  
        CALL phot%Photon_Electron_Scattering2( ) 
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        Scattering_loop: Do
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
            phot%scatter_times = phot%scatter_times + 1 
            if( phot%w_ini / phot%w_ini0 <= Terminate_Tolerence .or. &
                phot%scatter_times >= TerminateTime )exit
            !CALL Set_InI_Conditions_For_Next_Scattering( phot, sphot )   
            CALL phot%Set_InI_Conditions_For_Next_Scattering2( )   
            !CALL Determine_Next_Scattering_Site( phot, sphot ) 
            !write(*,fmt=*)'ssff222===', phot%Phot4k_CtrCF_ini(1),  
            CALL phot%Determine_P_Of_Scatt_Site_And_Quantities_At_p() 
            !if( phot%Phot4k_CtrCF_ini(1) > mec2 * 1.D1)exit 
            !write(*,fmt=*)'ssff222===', T_bb * 1.1D4,  mec2 * 8.D-1
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
            !if( phot%scatter_times >= 20 )exit  
            !if(   phot%Psi_I <= 1.D-1 )exit 
            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            CALL phot%Photon_Electron_Scattering2( ) 
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        END DO Scattering_loop
        !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        !write(*,*)'******',phot%scatter_times, phot%medium_case
  
        If ( mod(Num_Photons, 50000)==0 .and. myid == np-1 ) then 
            write(unit = *, fmt = *)'*******************************************************************' 
            write(unit = *, fmt = *)'***** The', Num_Photons,'th Photons have been scattered', &
                                  phot%scatter_times, &
                         'times and Escapted from the region !!!!!!!'      
            write(unit = *, fmt = *)'***** My Duty Photon Number is: ', myid, mydutyphot  
        endif
        If( Num_Photons > mydutyphot )EXIT 
    Enddo  
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
      If ( myid /= np-1 ) then  
          send_num  = ( vL_sc_up + 1 ) * 4 * 7 * Num_mu
          send_tag = 1  
          call MPI_SEND( phot%PolArrIQUV, send_num, MPI_DOUBLE_PRECISION, np-1, &
                        send_tag, MPI_COMM_WORLD, ierr)
          write(*, *)'Processor ', myid, ' has send PolarArrayI to Processor:', np-1   
      else  
          if (np-2 >= 0) then
              do RECV_SOURCE = 0, np-2 

                  recv_num = ( vL_sc_up + 1 ) * 4 * 7 * Num_mu

                  call MPI_RECV( IQUV_Recv, recv_num, MPI_DOUBLE_PRECISION, RECV_SOURCE, &
                                1, MPI_COMM_WORLD, status, ierr) 
                  write(*,*)'master Processor ', myid,' Receives I data from Processor:', RECV_SOURCE 
 
                  phot%PolArrIQUV = phot%PolArrIQUV + IQUV_Recv 

              enddo
          endif   
          write(*,*)'There are', phot%effect_number, 'of total', Total_Phot_Num, 'photons',&
                        'arrive at the plate of observer!!' 
          if( phot%num_mu_esti == 3 )then  
              open(unit=13, file = Savefilename, status="replace") 
              do i = 1, phot%num_mu_esti
                  do j = 0, vL_sc_up  
                      write(unit = 13, fmt = 200)phot%PolArrIQUV(1, 0: 6, i, j)! * 1.D60 
                  enddo
              enddo
          else
              open(unit=13, file=Savefilename, status="replace")  
              do j = 0, vL_sc_up 
                  write(unit = 13, fmt = 300)phot%PolArrIQUV(1, 6, 1: phot%num_mu_esti, j) 
              enddo 
          endif
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
          200 FORMAT(' ', ES15.6, '   ', ES15.6, '   ', ES15.6, '   ', ES15.6 ,'   ', &
                          ES15.6 ,'   ', ES15.6 ,'   ', ES15.6 )
          300 FORMAT(' ', '   ', ES15.6, '   ', ES15.6, '   ', ES15.6, '   ', ES15.6)
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
          close(unit=13)    
      endif   
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
    call MPI_FINALIZE ( ierr ) 
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    END SUBROUTINE mimick_of_ph_Slab_BoundReflc
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    END MODULE Method_Of_FLST_DiffuseReflec
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 

    
