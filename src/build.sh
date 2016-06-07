#! /bin/bash

################################################################################
# Build
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



# Set locations
THORN=PETSc
NAME=petsc-3.5.2
SRCDIR="$(dirname $0)"
BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
if [ -z "${PETSC_INSTALL_DIR}" ]; then
    INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
else
    echo "BEGIN MESSAGE"
    echo "Installing PETSc into ${PETSC_INSTALL_DIR}"
    echo "END MESSAGE"
    INSTALL_DIR=${PETSC_INSTALL_DIR}
fi
DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
PETSC_DIR=${INSTALL_DIR}

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
# PETSc's configuration variable has a different name, and accepts
# only a single (sic!) directory
MPI_INC_DIR="$(echo $(for dir in ${PETSC_MPI_EXTRA_INC_DIRS} ${MPI_INC_DIRS}; do echo ${dir}; done | head -n 1))"
if [ "${USE_RANLIB}" != 'yes' ]; then
    unset RANLIB
fi
unset LIBS
if echo '' ${ARFLAGS} | grep 64 > /dev/null 2>&1; then
    export OBJECT_MODE=64
fi
ARFLAGS=`echo ${ARFLAGS} | tr -d u`
# PETSc wants a serial make
MAKE="${MAKE} -j1"
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
cd ${SCRATCH_BUILD}
mkdir build external done 2> /dev/null || true
rm -rf ${BUILD_DIR} ${INSTALL_DIR}
mkdir ${BUILD_DIR} ${INSTALL_DIR}

echo "PETSc: Unpacking archive..."
pushd ${BUILD_DIR}
${TAR?} xzf ${SRCDIR}/../dist/${NAME}.tar.gz

echo "PETSc: Configuring..."
cd ${NAME}
MPI_LIB_LIST=""
PETSC_EXTRA_LIBS=""
for lib in ${MPI_LIBS} ${PETSC_MPI_EXTRA_LIBS}; do
    # Don't add "-l" for options already starting with a hyphen
    if ! echo "x${lib}" | grep -q '^x-'; then
        for lib_dir in ${MPI_LIB_DIRS} ${PETSC_MPI_EXTRA_LIB_DIRS}; do
            for suffix in a so dylib; do
                file=${lib_dir}/lib${lib}.${suffix}
                if [ -r ${file} ]; then
                    MPI_LIB_LIST="${MPI_LIB_LIST} ${file}"
                    break 2
                fi
                unset file
            done
        done
        if [ -z "${file}" ]; then
            echo "PETSc:    Could not find MPI library ${lib}, trying system default" >&2
            PETSC_EXTRA_LIBS="${PETSC_EXTRA_LIBS} -l${lib}"
        fi
    fi
done
BLAS_LAPACK_LIB_LIST=""
for lib in ${LAPACK_LIBS} ${PETSC_LAPACK_EXTRA_LIBS}; do
    # Don't add "-l" for options already starting with a hyphen
    if ! echo "x${lib}" | grep -q '^x-'; then
        for lib_dir in ${LAPACK_LIB_DIRS} ${PETSC_LAPACK_EXTRA_LIB_DIRS}; do
            for suffix in a so dylib; do
                file=${lib_dir}/lib${lib}.${suffix}
                if [ -r ${file} ]; then
                    BLAS_LAPACK_LIB_LIST="${BLAS_LAPACK_LIB_LIST} ${lib}"
                    break 2
                fi
                unset file
            done
        done
        if [ -z "${file}" ]; then
            echo "PETSc:    Could not find LAPACK library ${lib}, trying system default" >&2
            PETSC_EXTRA_LIBS="${PETSC_EXTRA_LIBS} -l${lib}"
        fi
    fi
done
for lib in ${BLAS_LIBS} ${PETSC_BLAS_EXTRA_LIBS}; do
    # Don't add "-l" for options already starting with a hyphen
    if ! echo "x${lib}" | grep -q '^x-'; then
        for lib_dir in ${BLAS_LIB_DIRS} ${PETSC_BLAS_EXTRA_LIB_DIRS}; do
            for suffix in a so dylib; do
                file=${lib_dir}/lib${lib}.${suffix}
                if [ -r ${file} ]; then
                    BLAS_LAPACK_LIB_LIST="${BLAS_LAPACK_LIB_LIST} ${lib}"
                    break 2
                fi
                unset file
            done
        done
        if [ -z "${file}" ]; then
            echo "PETSc:    Could not find BLAS library ${lib}, trying system default" >&2
            PETSC_EXTRA_LIBS="${PETSC_EXTRA_LIBS} -l${lib}"
        fi
    fi
done
PETSC_EXTRA_CPPFLAGS=""
for dir in $LAPACK_INC_DIRS $PETSC_LAPACK_EXTRA_INC_DIRS $BLAS_INC_DIRS $PETSC_BLAS_EXTRA_INC_DIRS $SYS_INC_DIRS; do
    if echo " $dir" | grep -q -e '^ -'; then
        PETSC_EXTRA_CPPFLAGS="${PETSC_EXTRA_CPPFLAGS} $dir"
    fi
done
BLAS_LIB_LIST="${BLAS_LAPACK_LIB_LIST}"
LAPACK_LIB_LIST="${BLAS_LAPACK_LIB_LIST}"
PETSC_EXTRA_LDFLAGS=""
for dir in $LAPACK_LIB_DIRS $PETSC_LAPACK_EXTRA_LIB_DIRS $BLAS_LIB_DIRS $PETSC_BLAS_EXTRA_LIB_DIRS $LIBDIRS; do
    PETSC_EXTRA_LDFLAGS="${PETSC_EXTRA_LDFLAGS} ${LIBDIR_PREFIX}${dir} ${RUNDIR_PREFIX}${dir}"
done
if [ "${CCTK_BLAS_INT8}" != 0 ]; then
    known_64_bit_blas_indices='--known-64-bit-blas-indices=yes'
fi
if [ -n "${PETSC_INT8}" -a "${PETSC_INT8}" != 0 ]; then
    with_64_bit_indices='--with-64-bit-indices=yes'
fi
PETSC_INT8=''
# Using --with-shared-libraries=0 to avoid using other, static
# libraries into PETSc's shared library, which doesn't work in general
./config/configure.py                                                      \
    --LDFLAGS="${LDFLAGS} ${PETSC_EXTRA_LDFLAGS}"                          \
    --LIBS="${PETSC_EXTRA_LIBS}"                                           \
    --doCleanup=0                                                          \
    --prefix=${INSTALL_DIR}                                                \
    --with-cpp="${CPP}"                                                    \
    --CPPFLAGS="${CPPFLAGS} ${PETSC_EXTRA_CPPFLAGS}"                       \
    --with-cc="${CC}"                                                      \
    --CFLAGS="${CFLAGS} ${LDFLAGS} ${PETSC_EXTRA_LDFLAGS}"                 \
    --with-cxx="${CXX}"                                                    \
    --CXXFLAGS="${CXXFLAGS} ${LDFLAGS} ${PETSC_EXTRA_LDFLAGS}"             \
    --with-fc=0                                                            \
    --with-ar="${AR}" --AR_FLAGS="${ARFLAGS}"                              \
    ${RANLIB:+--with-ranlib="${RANLIB}"}                                   \
    --with-shared-libraries=0                                              \
    --with-mpi=yes                                                         \
    ${MPI_INC_DIR:+--with-mpi-include="${MPI_INC_DIR}"}                    \
    ${MPI_LIB_LIST:+                                                       \
        --with-mpi-lib=[$(echo ${MPI_LIB_LIST} | sed -e 's/ /,/g')]}       \
    --with-mpi-compilers=no                                                \
    --with-mpiexec=false                                                   \
    ${with_64_bit_indices}                                                 \
    --with-ssl=no                                                          \
    --with-x=no                                                            \
    ${BLAS_LIB_LIST:+                                                      \
        --with-blas-lib=[$(echo ${BLAS_LIB_LIST} | sed -e 's/ /,/g')]}     \
    ${LAPACK_LIB_LIST:+                                                    \
        --with-lapack-lib=[$(echo ${LAPACK_LIB_LIST} | sed -e 's/ /,/g')]} \
    ${known_64_bit_blas_indices}                                           \
    --with-make="${MAKE}"
PETSC_ARCH=$(grep '^PETSC_ARCH=' conf/petscvariables |  \
    sed -e 's/^PETSC_ARCH=//')
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
