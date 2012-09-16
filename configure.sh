#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



################################################################################
# Search
################################################################################

if [ -z "${PETSC_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "PETSc selected, but PETSC_DIR not set. Checking some places..."
    echo "END MESSAGE"
    
    FILES="include/petsc.h"
    DIRS="/ /usr /usr/local /usr/lib/petsc /usr/local/petsc /usr/local/packages/petsc /usr/local/apps/petsc"
    for dir in $DIRS; do
        PETSC_DIR="$dir"
        for file in $FILES; do
            if [ ! -r "$dir/$file" ]; then
                unset PETSC_DIR
                break
            fi
        done
        if [ -n "$PETSC_DIR" ]; then
            break
        fi
    done
    
    if [ -z "$PETSC_DIR" ]; then
        echo "BEGIN MESSAGE"
        echo "PETSc not found"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Found PETSc in ${PETSC_DIR}"
        echo "END MESSAGE"
    fi
fi



################################################################################
# Build
################################################################################

if [ -z "${PETSC_DIR}"                                                  \
     -o "$(echo "${PETSC_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]
then
    echo "BEGIN MESSAGE"
    echo "Using bundled PETSc..."
    echo "END MESSAGE"
    
    # Set locations
    THORN=PETSc
    NAME=petsc-3.1-p8
    SRCDIR=$(dirname $0)
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${PETSC_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing PETSC into ${PETSC_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${PETSC_INSTALL_DIR}
    fi
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    PETSC_DIR=${INSTALL_DIR}
    
    if [ -e ${DONE_FILE} -a ${DONE_FILE} -nt ${SRCDIR}/dist/${NAME}.tar.gz \
                         -a ${DONE_FILE} -nt ${SRCDIR}/configure.sh ]
    then
        echo "BEGIN MESSAGE"
        echo "PETSc has already been built; doing nothing"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Building PETSc"
        echo "END MESSAGE"
        
        # Build in a subshell
        (
        exec >&2                # Redirect stdout to stderr
        if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
            set -x              # Output commands
        fi
        set -e                  # Abort on errors
        cd ${SCRATCH_BUILD}
        
        # Set up environment
        # This is where we will install PETSc, not where be are
        # building PETSc
        unset PETSC_DIR
        # Don't try to use Fortran compilers
        #if [ "${F90}" = "none" ]; then
        #    echo 'BEGIN MESSAGE'
        #    echo 'No Fortran 90 compiler available. Building PETSc library without Fortran support.'
        #    echo 'END MESSAGE'
        #    unset FC
        #    unset FFLAGS
        #else
        #    FC="${F90}"
        #    FFLAGS="${F90FLAGS}"
        #fi
        unset FC
        unset FFLAGS
        # PETSc's configuration variable has a different name, and
        # accepts only a single (sic!) directory
        MPI_INC_DIR=$(echo $(for dir in ${MPI_INC_DIRS}; do echo ${dir}; done | head -n 1))
        if [ "${USE_RANLIB}" != 'yes' ]; then
            unset RANLIB
        fi
        unset LIBS
        if echo '' ${ARFLAGS} | grep 64 > /dev/null 2>&1; then
            export OBJECT_MODE=64
        fi
        # Don't be confused by random existing variables
        unset HAVE_GSL
        unset GSL_DIR
        unset GSL_INC_DIRS
        unset GSL_LIB_DIRS
        unset GSL_LIBS
        unset HAVE_HDF5
        unset HDF5_DIR
        unset HDF5_INC_DIRS
        unset HDF5_LIB_DIRS
        unset HDF5_LIBS
        unset HAVE_HYPRE
        unset HYPRE_DIR
        unset HYPRE_INC_DIRS
        unset HYPRE_LIB_DIRS
        unset HYPRE_LIBS
        unset HAVE_LIBJPEG
        unset LIBJPEG_DIR
        unset LIBJPEG_INC_DIRS
        unset LIBJPEG_LIB_DIRS
        unset LIBJPEG_LIBS
        echo "PETSc: Current environment settings:"
        env | sort
        
        echo "PETSc: Preparing directory structure..."
        mkdir build external done 2> /dev/null || true
        rm -rf ${BUILD_DIR} ${INSTALL_DIR}
        mkdir ${BUILD_DIR} ${INSTALL_DIR}
        
        echo "PETSc: Unpacking archive..."
        pushd ${BUILD_DIR}
        ${TAR?} xzf ${SRCDIR}/dist/${NAME}.tar.gz
        
        echo "PETSc: Configuring..."
        cd ${NAME}
        MPI_LIB_LIST=$(echo $(
                for lib in ${MPI_LIBS} ${PETSC_MPI_EXTRA_LIBS}; do
                    for lib_dir in ${MPI_LIB_DIRS} ${PETSC_MPI_EXTRA_LIB_DIRS}; do
                        for suffix in a so dylib; do
                            file=${lib_dir}/lib${lib}.${suffix}
                            if [ -r ${file} ]; then
                                echo ${file}
                                break 2
                            fi
                            unset file
                        done
                    done
                    if [ -z "${file}" ]; then
                        echo "PETSc:    Could not find MPI library ${lib}" >&2
                    fi
                done))
        BLAS_LIB_LIST=$(echo $(
                for lib in ${BLAS_LIBS} ${PETSC_BLAS_EXTRA_LIBS}; do
                    for lib_dir in ${BLAS_LIB_DIRS} ${PETSC_BLAS_EXTRA_LIB_DIRS}; do
                        for suffix in a so dylib; do
                            file=${lib_dir}/lib${lib}.${suffix}
                            if [ -r ${file} ]; then
                                echo ${file}
                                break 2
                            fi
                            unset file
                        done
                    done
                    if [ -z "${file}" ]; then
                        echo "PETSc:    Could not find BLAS library ${lib}" >&2
                    fi
                done))
        LAPACK_LIB_LIST=$(echo $(
                for lib in ${LAPACK_LIBS} ${PETSC_LAPACK_EXTRA_LIBS}; do
                    for lib_dir in ${LAPACK_LIB_DIRS} ${PETSC_LAPACK_EXTRA_LIB_DIRS}; do
                        for suffix in a so dylib; do
                            file=${lib_dir}/lib${lib}.${suffix}
                            if [ -r ${file} ]; then
                                echo ${file}
                                break 2
                            fi
                            unset file
                        done
                    done
                    if [ -z "${file}" ]; then
                        echo "PETSc:    Could not find LAPACK library ${lib}" >&2
                    fi
                done))
#            --LDFLAGS="${LDFLAGS}"
#            --with-shared=0
        ./config/configure.py                                                 \
            --doCleanup=0                                                     \
            --prefix=${INSTALL_DIR}                                           \
            --with-cpp="${CPP}" --CPPFLAGS="${CPPFLAGS}"                      \
            --with-cc="${CC}" --CFLAGS="${CFLAGS}"                            \
            --with-cxx="${CXX}" --CXXFLAGS="${CXXFLAGS}"                      \
            --with-fc=0                                                       \
            --with-ar="${AR}"                                                 \
            --AR_FLAGS="${ARFLAGS}"                                           \
            ${RANLIB:+--with-ranlib="${RANLIB}"}                              \
            --with-mpi=yes                                                    \
            ${MPI_INC_DIR:+--with-mpi-include="${MPI_INC_DIR}"}               \
            ${MPI_LIB_LIST:+--with-mpi-lib=[$(echo ${MPI_LIB_LIST} |          \
                    sed -e 's/ /,/g')]}                                       \
            --with-mpi-compilers=no                                           \
            --with-mpiexec=false                                              \
            --with-x=no                                                       \
            ${BLAS_LIB_LIST:+--with-blas-lib=[$(echo ${BLAS_LIB_LIST} |       \
                    sed -e 's/ /,/g')]}                                       \
            ${LAPACK_LIB_LIST:+--with-lapack-lib=[$(echo ${LAPACK_LIB_LIST} | \
            sed -e 's/ /,/g')]}                                               \
            --with-make="${MAKE}"
        PETSC_ARCH=$(grep '^PETSC_ARCH=' conf/petscvariables | sed -e 's/^PETSC_ARCH=//')
        echo "PETSc: PETSC_ARCH is \"${PETSC_ARCH}\""
        echo "${PETSC_ARCH}" > PETSC_ARCH
        
        echo "PETSc: Building..."
        ${MAKE} PETSC_DIR="${BUILD_DIR}/${NAME}" PETSC_ARCH="${PETSC_ARCH}" all
        
        echo "PETSc: Installing..."
        ${MAKE} PETSC_DIR="${BUILD_DIR}/${NAME}" PETSC_ARCH="${PETSC_ARCH}" install
        popd
        
        echo "PETSc: Cleaning up..."
        rm -rf ${BUILD_DIR}
        
        date > ${DONE_FILE}
        echo "PETSc: Done."
        
        )
        
        if (( $? )); then
            echo 'BEGIN ERROR'
            echo 'Error while building PETSc. Aborting.'
            echo 'END ERROR'
            exit 1
        fi
    fi
    
fi



################################################################################
# Set options
################################################################################

if [ -n "${THORN}" ]; then
    
    # We built PETSc ourselves, and know what is going on
    PETSC_INC_DIRS="${PETSC_DIR}/include ${PETSC_MPI_INC_DIR}"
    PETSC_LIB_DIRS="${PETSC_DIR}/lib ${PETSC_MPI_LIB_DIRS}"
    PETSC_LIBS="petsc ${PETSC_MPI_LIBS}"
    
else
    
    # We are using a pre-installed PETSc, and have to find out how it
    # was installed. This differs between PETSc versions.
    
    if [ -z "$PETSC_ARCH_LIBS" ]; then
        case "$PETSC_ARCH" in
            alpha)         PETSC_ARCH_LIBS='dxml' ;;
            IRIX64)        PETSC_ARCH_LIBS='fpe blas complib.sgimath' ;;
            linux)         PETSC_ARCH_LIBS='flapack fblas g2c mpich'  ;;
            linux_intel)   PETSC_ARCH_LIBS='mkl_lapack mkl_def guide' ;;
            linux-gnu)     PETSC_ARCH_LIBS='mkl_lapack mkl_def guide' ;;
            linux64_intel) PETSC_ARCH_LIBS='mkl_lapack mkl guide' ;;
            rs6000_64)     PETSC_ARCH_LIBS='essl' ;;
            *)
                echo 'BEGIN ERROR'
                echo "There is no support for external PETSc installations"
                echo "for the PETSc architecture '${PETSC_ARCH}'."
                echo "Please set the variable PETSC_ARCH_LIBS manually,"
                echo "and/or have Cactus build PETSc,"
                echo "and/or send a request to <cactusmaint@cactuscode.org>."
                echo 'END ERROR'
                exit 2
        esac
    fi
    
    # Set version-specific library directory
    # (version 2.3.0 and newer use different library directories)
    if [ -e "${PETSC_DIR}/lib/${PETSC_ARCH}" -o -e "${PETSC_DIR}/lib/libpetsc.a" ]; then
        PETSC_LIB_INFIX=''
    else
        PETSC_LIB_INFIX='/libO'
    fi
    
    # Set version-specific libraries
    # (version 2.2.0 and newer do not have libpetscsles.a any more)
    if [ -e "${PETSC_DIR}/lib${PETSC_LIB_INFIX}/${PETSC_ARCH}/libpetscksp.a" -o -e "${PETSC_DIR}/lib/libpetscksp.a" -o -e "${PETSC_DIR}/${PETSC_ARCH}/lib/libpetscksp.a" ]; then
        PETSC_SLES_LIBS="petscksp"
    else
        PETSC_SLES_LIBS="petscsles"
    fi
    
    # Set the PETSc libs, libdirs and includedirs
    PETSC_INC_DIRS="${PETSC_DIR}/include ${PETSC_DIR}/bmake/${PETSC_ARCH} ${PETSC_DIR}/${PETSC_ARCH}/include"
    PETSC_LIB_DIRS="${PETSC_DIR}/lib${PETSC_LIB_INFIX}/${PETSC_ARCH} ${PETSC_DIR}/lib ${PETSC_DIR}/${PETSC_ARCH}/lib"
    # (version 3 and newer place everything into a single library)
    if [ -e "${PETSC_DIR}/lib${PETSC_LIB_INFIX}/${PETSC_ARCH}/libpetscvec.a" -o -e "${PETSC_DIR}/lib/libpetscvec.a" -o -e "${PETSC_DIR}/${PETSC_ARCH}/lib/libpetscvec.a" ]; then
        PETSC_LIBS="petscts petscsnes ${PETSC_SLES_LIBS} petscdm petscmat petscvec petsc ${PETSC_ARCH_LIBS}"
    else
        PETSC_LIBS="petsc ${PETSC_ARCH_LIBS}"
    fi
    
fi



################################################################################
# Configure Cactus
################################################################################

# Re-export MPI settings (to all PETSc users)
echo 'BEGIN INCLUDE'
echo '"cctki_MPI.h"'
echo 'END INCLUDE'

echo 'BEGIN MAKE_DEFINITION'
echo 'include $(BINDINGS_DIR)/Configuration/Capabilities/make.MPI.defn'
echo 'END MAKE_DEFINITION'

echo 'BEGIN MAKE_DEPENDENCY'
echo 'include $(BINDINGS_DIR)/Configuration/Capabilities/make.MPI.deps'
echo 'END MAKE_DEPENDENCY'

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "HAVE_PETSC     = 1"
echo "PETSC_DIR      = ${PETSC_DIR}"
echo "PETSC_ARCH     = ${PETSC_ARCH}"
echo "PETSC_INC_DIRS = ${PETSC_INC_DIRS}"
echo "PETSC_LIB_DIRS = ${PETSC_LIB_DIRS}"
echo "PETSC_LIBS     = ${PETSC_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(PETSC_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(PETSC_LIB_DIRS)'
echo 'LIBRARY           $(PETSC_LIBS)'
