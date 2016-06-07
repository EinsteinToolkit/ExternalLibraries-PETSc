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

THORN=PETSc



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
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${PETSC_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing PETSc into ${PETSC_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${PETSC_INSTALL_DIR}
    fi
    PETSC_BUILD=1
    PETSC_DIR=${INSTALL_DIR}
else
    PETSC_BUILD=
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    if [ ! -e ${DONE_FILE} ]; then
        mkdir ${SCRATCH_BUILD}/done 2> /dev/null || true
        date > ${DONE_FILE}
    fi
fi



################################################################################
# Set options
################################################################################

if [ -n "${INSTALL_DIR}" ]; then
    
    # We built PETSc ourselves, and know what is going on
    PETSC_INC_DIRS="${PETSC_DIR}/include"
    PETSC_LIB_DIRS="${PETSC_DIR}/lib"
    PETSC_LIBS="petsc"
    
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

# Pass configuration options to build script
echo "BEGIN MAKE_DEFINITION"
echo "PETSC_BUILD                 = ${PETSC_BUILD}"
echo "PETSC_INT8                  = ${PETSC_INT8}"
echo "PETSC_BLAS_EXTRA_LIB_DIRS   = ${PETSC_BLAS_EXTRA_LIB_DIRS}"
echo "PETSC_BLAS_EXTRA_LIBS       = ${PETSC_BLAS_EXTRA_LIBS}"
echo "PETSC_LAPACK_EXTRA_LIB_DIRS = ${PETSC_LAPACK_EXTRA_LIB_DIRS}"
echo "PETSC_LAPACK_EXTRA_LIBS     = ${PETSC_LAPACK_EXTRA_LIBS}"
echo "PETSC_MPI_EXTRA_LIB_DIRS    = ${PETSC_MPI_EXTRA_LIB_DIRS}"
echo "PETSC_MPI_EXTRA_LIBS        = ${PETSC_MPI_EXTRA_LIBS}"
echo "PETSC_INSTALL_DIR           = ${PETSC_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

PETSC_INC_DIRS="$(${CCTK_HOME}/lib/sbin/strip-incdirs.sh ${PETSC_INC_DIRS})"
PETSC_LIB_DIRS="$(${CCTK_HOME}/lib/sbin/strip-libdirs.sh ${PETSC_LIB_DIRS})"

# Pass options to Cactus
echo "BEGIN DEFINE"
echo "PETSC_SKIP_COMPLEX 1   /* Don't include <complex.h> */"
echo "END DEFINE"

echo "BEGIN MAKE_DEFINITION"
echo "PETSC_DIR      = ${PETSC_DIR}"
echo "PETSC_ARCH     = ${PETSC_ARCH}"
echo "PETSC_INC_DIRS = ${PETSC_INC_DIRS}"
echo "PETSC_LIB_DIRS = ${PETSC_LIB_DIRS}"
echo "PETSC_LIBS     = ${PETSC_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(PETSC_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(PETSC_LIB_DIRS)'
echo 'LIBRARY           $(PETSC_LIBS)'
