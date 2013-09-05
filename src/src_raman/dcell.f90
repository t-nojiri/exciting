!
Subroutine dcell (vqpc, eigv, dph)
!
! sets up (super)cell with atom displacements to compute potential and 
! changes in dielectric function 
!
      Use mod_phonon
      use mod_qpoint
      use mod_atoms
      use modmain, only: maxatoms
      use mod_lattice, only: ainv
      use m_raman_utils
      use raman_ew, only: fgew
      Use modinput
      Implicit None
! arguments
      Real (8), Intent (in) :: vqpc(3)
      Complex (8), Intent (In) :: eigv(3*natmtot)
      Real (8), Intent (In) :: dph
! local variables
      Integer :: js, ja, na, i, n, iv(3), iat, i_n
      Integer :: i1, i2, i3, m(3, 3)
      Real (8) :: v1(3), v2(3), v3(3), v4(3), dmin, t1, len_u, len_v, len_u2
      Real (8) :: u_i(3)
      real(8) :: r3dist
      external r3dist
!
! store original lattice vectors
      avec0 (:, :) = input%structure%crystal%basevect(:, :)
! check for Gamma-point phonon
      If ((vqpc(1) .Eq. 0) .And. (vqpc(2) .Eq. 0) .And. (vqpc(3) .Eq. 0)) Then
         m(:, :) = 0
         m(1, 1) = 1
         m(2, 2) = 1
         m(3, 3) = 1
         nphcell = 1
         Go To 10
      End If
! find the first lattice vector
      dmin = 1.d8
      Do i1 = -ngridq(1), ngridq(1)
         Do i2 = -ngridq(2), ngridq(2)
            Do i3 = -ngridq(3), ngridq(3)
               t1 = dble(i1)*vqpc(1) + dble(i2)*vqpc(2) + dble(i3)*vqpc(3)
               If (Abs(t1-Nint(t1)) .Lt. input%structure%epslat) Then
                  v1(:) = dble(i1)*avec0(:, 1) + dble(i2)*avec0(:, 2) + dble(i3)*avec0(:, 3)
                  t1 = Sqrt(v1(1)**2+v1(2)**2+v1(3)**2)
                  If ((t1 .Lt. dmin) .And. (t1 .Gt. input%structure%epslat)) Then
                     m(1, 1) = i1
                     m(2, 1) = i2
                     m(3, 1) = i3
                     dmin = t1
                  End If
               End If
            End Do
         End Do
      End Do
! find the second lattice vector
      dmin = 1.d8
      Do i1 = -ngridq(1), ngridq(1)
         Do i2 = -ngridq(2), ngridq(2)
            Do i3 = -ngridq(3), ngridq(3)
               t1 = dble(i1)*vqpc(1) + dble(i2)*vqpc(2) + dble(i3)*vqpc(3)
               If (Abs(t1-Nint(t1)) .Lt. input%structure%epslat) Then
! area defined by first two lattice vectors
                  n = (i2*m(3, 1)-i3*m(2, 1))**2 + (i3*m(1, 1)-i1*m(3, 1))**2 + (i1*m(2, 1)-i2*m(1, 1))**2
                  If (n .Ne. 0) Then
                     v1(:) = dble(i1)*avec0(:, 1) + dble(i2)*avec0(:, 2) + dble(i3)*avec0(:, 3)
                     t1 = v1(1)**2 + v1(2)**2 + v1(3)**2
                     If (t1 .Lt. dmin) Then
                        m(1, 2) = i1
                        m(2, 2) = i2
                        m(3, 2) = i3
                        dmin = t1
                     End If
                  End If
               End If
            End Do
         End Do
      End Do
! find the third lattice vector
      nphcell = 0
      dmin = 1.d8
      Do i1 = -ngridq(1), ngridq(1)
         Do i2 = -ngridq(2), ngridq(2)
            Do i3 = -ngridq(3), ngridq(3)
               t1 = dble(i1)*vqpc(1) + dble(i2)*vqpc(2) + dble(i3)*vqpc(3)
               If (Abs(t1-Nint(t1)) .Lt. input%structure%epslat) Then
! number of primitive unit cells in supercell
                  n = m(1, 2) * (i2*m(3, 1)-i3*m(2, 1)) + m(2, 2)*(i3*m(1, 1)-i1*m(3, 1)) + m(3, 2)*(i1*m(2, 1)-i2*m(1, 1))
                  If (n .Ne. 0) Then
                     v1(:) = dble(i1)*avec0(:, 1) + dble(i2)*avec0(:, 2) + dble(i3)*avec0(:, 3)
                     t1 = v1(1)**2 + v1(2)**2 + v1(3)**2
                     If (t1 .Lt. dmin) Then
                        nphcell = Abs (n)
                        m(1, 3) = i1
                        m(2, 3) = i2
                        m(3, 3) = i3
                        dmin = t1
                     End If
                  End If
               End If
            End Do
         End Do
      End Do
      If (nphcell .Eq. 0) Then
         Write (*,*)
         Write (*, '("Error(dcell): unable to generate supercell")')
         Write (*,*)
         Stop
      End If
10    Continue
! new lattice vectors
      Do i = 1, 3
         input%structure%crystal%basevect(:, i) = dble(m(1, i))*avec0(:, 1) + dble(m(2, i))*avec0(:, 2) + dble(m(3, i))*avec0 (:, 3)
      End Do
! inverse of lattice vector matrix
      Call r3minv (input%structure%crystal%basevect, ainv)
! generate offset vectors for each primitive cell in the supercell
      n = 1
      vphcell(:, 1) = 0.d0
      Do i1 = -ngridq(1), ngridq(1)
         Do i2 = -ngridq(2), ngridq(2)
            Do i3 = -ngridq(3), ngridq(3)
               If (n .Eq. nphcell) Go To 30
               v1(:) = dble(i1)*avec0(:, 1) + dble(i2)*avec0(:, 2) + dble(i3)*avec0(:, 3)
               Call r3mv (ainv, v1, v2)
               Call r3frac (input%structure%epslat, v2, iv)
               Call r3mv (input%structure%crystal%basevect, v2, v1)
               Do i = 1, n
                  t1 = Abs(v1(1) - vphcell(1, i)) + Abs(v1(2) - vphcell(2, i)) + Abs(v1(3) - vphcell(3, i))
                  If (t1 .Lt. input%structure%epslat) Go To 20
               End Do
               n = n + 1
               vphcell(:, n) = v1(:)
20             Continue
            End Do
         End Do
      End Do
      Write (*,*)
      Write (*, '("Error(dcell): unable to generate offset vectors in supercell")')
      Write (*,*)
      Stop
30    Continue
! set up the supercell with a size of nphcell*natoms(js) atoms for each species js
      do js = 1, nspecies
        do ja = 1, natoms(js)
            deallocate(input%structure%speciesarray(js)%species%atomarray(ja)%atom)
        end do
        deallocate(input%structure%speciesarray(js)%species%atomarray)
        allocate(input%structure%speciesarray(js)%species%atomarray(nphcell*natoms(js)))
        do ja = 1, nphcell*natoms(js)
            allocate(input%structure%speciesarray(js)%species%atomarray(ja)%atom)
        end do
      end do
! compute total length of (real) displacement vector u per cell
!     iat = 0
!     len_u = 0.d0
!     Do js = 1, nspecies
!        Do ja = 1, natoms(js)
!           iat = iat + 1
!           Do i_n = 1, nphcell
!              t1 = dot_product(vqpc(:), vphcell(:, i_n))
!              do i = 1, 3
!                 len_u = len_u + ( dble(eigv(3*(iat-1)+i))*cos(t1) - &
!                   &              aimag(eigv(3*(iat-1)+i))*sin(t1) )**2 / spmass(js) 
!              enddo
!           enddo
!        enddo
!     enddo
!     len_u = sqrt( len_u / dble(nphcell) )
      call getfgew ( eigv )
!     write(*,*) 'len_u, 1/sqrt(fgew) ',len_u,1.d0/sqrt(fgew)
      len_u2 = 0.d0
! set up new atomic positions
      iat = 0
      Do js = 1, nspecies
         na = 0
         Do ja = 1, natoms(js)
            iat = iat + 1
            Do i_n = 1, nphcell
               na = na + 1
               v1(:) = vphcell(:, i_n) + atposc(:, ja, js) ! cartesian, Bohr
               write(*,'("v1(:) orig ",3f8.4)') v1(:)
! add displacement along phonon eigenvector
               t1 = dot_product(vqpc(:), vphcell(:, i_n))
               u_i(:) = dble( eigv((3*(iat-1)+1):(3*iat)) )*cos(t1) - &
                   &   aimag( eigv((3*(iat-1)+1):(3*iat)) )*sin(t1)
! displacement with |u| = dph
!              u_i = u_i / sqrt( dble(nphcell) ) / len_u * dph / sqrt( spmass(js) )
               u_i = u_i / sqrt( dble(nphcell) ) * sqrt(fgew) * dph / sqrt( spmass(js) )
               len_u2 = len_u2 + u_i(1)**2 + u_i(2)**2 + u_i(3)**2
               write(*,'("u_i(:) c ",3f8.4)') u_i(:)
               call r3mv (ainv, u_i, v2)
               write(*,'("u_i(:) l ",3f8.4)') v2(:)
               v1(:) = v1(:) + u_i(:)                      ! shift atoms
               write(*,'("v1(:) shift",3f8.4)') v1(:)
! convert to new lattice coordinates
               Call r3mv (ainv, v1, input%structure%speciesarray(js)%species%atomarray(na)%atom%coord(:))
               write(*,'("atpos(:) latt ",2i5,3f8.4)') js,na, &
      &                     input%structure%speciesarray(js)%species%atomarray(na)%atom%coord(:)
               if (iat .eq. 1) then
                Call r3mv (input%structure%crystal%basevect, &
      &                     input%structure%speciesarray(js)%species%atomarray(na)%atom%coord(:), v3)
               elseif (iat .eq. 2) then
                Call r3mv (input%structure%crystal%basevect, &
      &                     input%structure%speciesarray(js)%species%atomarray(na)%atom%coord(:), v4)
               endif
               Call r3frac (input%structure%epslat, input%structure%speciesarray(js)%species%atomarray(na)%atom%coord(:), iv)
               write(*,'("atpos(:) latt 0-1 ",2i5,3f8.4)') js,na,&
      &                     input%structure%speciesarray(js)%species%atomarray(na)%atom%coord(:)
            End Do
         End Do
         natoms (js) = na
      End Do
! muffin-tin magnetic fields should be zero
      Do js = 1, nspecies
         Do ja = 1, natoms (js)
            input%structure%speciesarray(js)%species%atomarray(ja)%atom%bfcmt(:) = 0.d0
         End Do
      End Do
!
      write(*,*) 'len_u2 ',sqrt(len_u2)
      write(*,'("v1(:) at1 ",3f8.4)') v3(:)
      write(*,'("v1(:) at2 ",3f8.4)') v4(:)
      write(*, '("Atom distance ",f8.4)') r3dist(v3, v4)
      Return
End Subroutine
