#!/bin/bash
#SBATCH --cpus-per-task=16
#SBATCH --mem=35GB
#SBATCH --time=24:00:00
#
#  To use a GPU (you should if one is available), submit using
#
#  sbatch --gres=gpu anoa-chain.sh
#
#  or, modify the SBATCH line
#
#   #SBATCH --gres=gpu
#

uname -a
date

# Run an ANOA fit with GUNDAM.  This should be run in the directory where
# the output belongs.  This is configured for GPUs by default, so you may
# need to change the #SBATCH lines above.
#
# Environment variables that the control behavior
# 
# GUNDAM_CONFIG    -- Set the config file base directory
# GUNDAM_NAME      -- Set the base name for the job (default: "job")
# GUNDAM_OPTIONS   -- Command line options for GUNDAM 
# GUNDAM_OVERRIDES -- Override files for GUNDAM
# GUNDAM_INSTALL   -- The installation location for GUNDAM
# GUNDAM_PATH      -- Search path for GUNDAM when GUNDAM_INSTALL missing
# OA_INPUT_FOLDER  -- The input file location
# GUNDAM_INPUTS    -- Search path for input files when OA_INPUT_FOLDER missing
#
# Set up from the command line (this overrides the environment
# variables that control the behavior)
#
# -C config   -- The configuration directory to use.
#
# -n name     -- The job name.  This is used to construct the output
#                directory
#
# -O override -- Add an override file from the config/overrides directory
#
# -o string   -- Add gundam option
#
# -G gundam   -- Override the gundam installation (otherwise, search a path)
#
# -I inputs   -- Override the inputs location (otherwise, search a path)
#
# -N          -- Start a new MCMC chain.

usage () {
    cat <<EOF
USAGE:
    $(basename $0) [-C config] [-n name] [-O override ] [-o gundam_option] \
                [-G gundam_installation] [-I inputs] [-N]         

    Run an GUNDAM MCMC chain.  This is mainly intended to be used to
    run a batch job, but can be run interactively.  Most of the time,
    you only want to set the job "name", the "override" files, and
    possibly "gundam_option" values to pass to GUNDAM.

OPTIONS:

     -C config   -- Set the top level directory for the configuration.
                    This directory should contain the config_DUNE.yaml file.

     -n name     -- The job name.  This is used to construct the output
                    directory name.  The output directory is created as a
                    sub-directory of where this command is run.

     -O override -- Add an override file from the config/overrides directory.
                    Check the GUNDAM documentation for details on how to use
                    an override file.  This adds a --override-files <override>
                    option to the gundamFitter command line

     -o string   -- Add gundam option.  The string is directly copied to the
                    gundamFitter command line.

     -G gundam   -- Override the gundam installation location (otherwise,
                    a default search path is used).  The installation location
                    must contain the gundam setup.sh script.

     -I inputs   -- Override the inputs location (otherwise, a default
                    search a path is used)

     -N          -- Start a new MCMC chain.

EOF
}

OPTIND=1
while getopts ":C:n:O:o:N" OPTVAL; do
    case "${OPTVAL}" in
        C)
            GUNDAM_CONFIG=${OPTARG}
        ;;
        n)
            GUNDAM_NAME=${OPTARG}
        ;;
        O)
            GUNDAM_OVERRIDES+=":${OPTARG}"
        ;;
        o)
            GUNDAM_OPTIONS+=" ${OPTARG}"
            ;;
        G)
            GUNDAM_INSTALL="${OPTARG}"
            ;;
        I)
            OA_INPUT_FOLDER="${OPTARG}"
            ;;
        N)
            NEWCHAIN=" -N "
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# If no override files are provided, then add one to start the MCMC.
# If overrides are provided by the command line (or environment), then
# an MCMC config will need to be provided, or strange things will
# happen.
echo GUNDAM OVERRIDES: ${GUNDAM_OVERRIDES:="configMcmc.yaml"}

##############################################################
# Adjust this section for your local machine.  These need to be
# absolute paths accessible from the job directory.
##############################################################

##############################################################
# Absolute path to the config file to be used.  The default should be
# edited locally
if [ ! -n "${GUNDAM_CONFIG}" ]; then
    GUNDAM_CONFIG=/home/mcgrew/work/dune/software/OscAna/gudi-anoa-sen25a/devel
fi
CONFIG_FILE=${GUNDAM_CONFIG}/config_DUNE.yaml

##############################################################
# Define the override files to use (if any)
CONFIG_OVERRIDE=""
if [ -n "${GUNDAM_OVERRIDES}" ]; then
    for i in ${GUNDAM_OVERRIDES//:/ }; do
        _overrideFile_=${GUNDAM_CONFIG}/overrides/${i}
        if [ ! -f ${_overrideFile_} ]; then
            echo OVERRIDE FILE NOT FOUND: ${i}
            echo file must be in ${GUNDAM_CONFIG}/overrides
            exit 1
        fi
        echo OVERRIDE FILE: ${_overrideFile_}
        CONFIG_OVERRIDE+=" --override-files ${_overrideFile_}"
    done
fi

##############################################################
# Choose the version of GUNDAM to be running.  GUNDAM should usually
# be installed in a sub-directory named after the release
# (e.g. main. rel-2.0.0, lts-1.8.8, etc).  GUNDAM should have been
# installed using "gundam-build" and will be placed in a machine
# dependent directory.  The target is the machine type that GUNDAM was
# compiled for.  The gundam setup.sh file is created when GUNDAM is
# compiled and is installed at
# ${GUNDAM_ROOT}/${GUNDAM_RELEASE}/${GUNDAM_TARGET}/setup.sh
if [ ! -n "${GUNDAM_INSTALL}" ]; then
    if [ ! -n "${GUNDAM_PATH}" ]; then
        # Add a path to try, otherwise the path comes from the environment
        GUNDAM_PATH+=":$(realpath ${PWD})"
        GUNDAM_PATH+=":${HOME}/work/projects/gundam/devel"
        # GUNDAM_PATH+=":${HOME}/work/projects/gundam/main"
        # GUNDAM_PATH+=":${HOME}/work/projects/gundam/lts_1.8.x"
    fi
    echo Find GUNDAM implementation
    for i in ${GUNDAM_PATH//:/ }; do
        echo LOOK FOR GUNDAM: ${i}
        for f in $(find ${i} -wholename "*/bin/gundamFitter"); do
            if [ -x ${f} ]; then
                echo FOUND: ${f}
                GUNDAM_INSTALL=$(dirname $(dirname ${f}))
                break 2;
            fi
        done
    done
fi

##############################################################
# Absolute path of the simulation input files.  This is usually the
# top of the inputs directory hierarchy, but for ATM, it points to
# the directory with the actual files.
##############################################################
export OA_INPUT_FOLDER

## Check some "well known" locations for the input files
if [ ! -n "${OA_INPUT_FOLDER}" ]; then
    if [ ! -n "${GUNDAM_INPUTS}" ]; then
        GUNDAM_INPUTS=":/gpfs/scratch/uyevarouskay/atm/gundam_files_fin_v12"
        GUNDAM_INPUTS+=":/pnfs/dune/persistent/users/weishi/OA-inputs/atm_reprocessed_v2"
        GUNDAM_INPUTS+=":/storage/shared/DUNE/OA-inputs/atm/gudi-inputs/v3"
        GUNDAM_INPUTS+=":/home/mcgrew/data/dune/OA-inputs/atm/gudi-inputs/v3"
    fi
    for i in ${GUNDAM_INPUTS//:/ }; do
        echo LOOK FOR INPUTS: ${i}
        if [ -d "${i}" ]; then
            OA_INPUT_FOLDER=${i}
            break;
        fi
    done
fi

if [ ! -d ${OA_INPUT_FOLDER} ]; then
    echo MISSING INPUT FOLDER
    echo Not found: ${OA_INPUT_FOLDER}
    exit 1
fi

##############################################################
# Absolute path to the output directory to be used.
# OUTPUT_ROOT=/storage/shared/mcgrew/dune/OscAna/
OUTPUT_ROOT=$(realpath $(pwd))

##############################################################
# Setup GUNDAM options (but only when not supplied from command line)
if [ ! -n "${GUNDAM_OPTIONS}" ]; then
    GUNDAM_OPTIONS="-t 8"
    GUNDAM_OPTIONS+=" --asimov"
    GUNDAM_OPTIONS+=" --kick-mc 0.5"
    GUNDAM_NAME=${GUNDAM_NAME:="asimov"}
    # GUNDAM_OPTIONS+=" --gpu"
    # GUNDAM_OPTIONS+=" --dry-run"
    # GUNDAM_OPTIONS+=" --cpu"
    # GUNDAM_OPTIONS+=" --cache-manager off"
    # GUNDAM_OPTIONS+=" --scan"
    # GUNDAM_OPTIONS+=" --debug"
fi

#############################################################
# Define a possible prefix for the gundamFitter.  This is usually
# blank, but can be used to run gprofng (for profiling), or gdb (for
# debugging).  GPROFNG will collect the information into the outout
# directory.  GDB must be run interactively, so make sure you disable
# the "tee" that is part of the gundamFitter command.
PREFIX_COMMAND=""
# PREFIX_COMMAND="gprofng collect app -o ${OUTPUT_DIR}/gundumFitter.er"
# PREFIX_COMMAND="gdb --args"

# Check that GUNDAM can be setup.
if [ -f ${GUNDAM_INSTALL}/setup.sh ]; then
    source ${GUNDAM_INSTALL}/setup.sh
else
    echo GUNDAM INSTALLATION NOT FOUND -- setup.sh is missing
    echo ${GUNDAM_INSTALL}
    exit 1
fi

# Check that GUNDAM was found
if which gundamFitter > /dev/null; then
    echo GUNDAM WAS CONFIGURED
    GUNDAM_FITTER=$(which gundamFitter)
else
    echo GUNDAM NOT CONFIGURED
    exit 1
fi

# Check that gundamContinue was found
if which gundamContinue > /dev/null; then
    echo GUNDAM CONTINUE WAS CONFIGURED
    GUNDAM_CONTINUE=$(which gundamContinue)
else
    echo GUNDAM NOT CONFIGURED
    exit 1
fi


# Check the the config file is found
if [ ! -f ${CONFIG_FILE} ]; then
    ls $(dirname ${CONFIG_FILE})
    echo Missing config file ${CONFIG_FILE}
    exit 1
fi

# Set the job name.  This cannot be read from the command line since
# the command line is rewritten by slurm.
if [ ! -n "${GUNDAM_NAME}" ]; then
    GUNDAM_NAME=job
fi
JOB_ID=0000
if [ ${#SLURM_JOB_ID} -gt 0 ]; then
    JOB_ID=${SLURM_JOB_ID}
fi
if [ ${#SLURM_ARRAY_TASK_ID} -gt 0 ]; then
    JOB_ID="${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
fi

JOB_BASE="anoa-${GUNDAM_NAME}-chain"
JOB_NAME="${JOB_BASE}-${JOB_ID}-$(date +%y%m%d-%H%M)"
JOB_DIR=$(realpath $(pwd))

echo JOB BASE: ${JOB_BASE}
echo JOB NAME: ${JOB_NAME}
echo JOB ROOT: ${JOB_DIR}
echo JOB ID: ${JOB_ID}
echo CONFIG FILE: ${CONFIG_FILE}
echo OVERRIDES: ${CONFIG_OVERRIDE}
echo GUNDAM OPTIONS: ${GUNDAM_OPTIONS}
echo INPUTS: ${OA_INPUT_FOLDER}

# Make output directory in the "jobs" area.
OUTPUT_DIR=${OUTPUT_ROOT}/${JOB_BASE}-output
OUTPUT_LOG=${OUTPUT_DIR}/output_${JOB_NAME}.log

mkdir -p ${OUTPUT_DIR}

###############################################
# Check if the slurm output can be found, and if it can be linked into
# the output directory.  If there is a slurm log file, put it in the
# output directory for safe keeping. Be careful since the file system
# might not be sync'ed.
if [ ${#SLURM_JOB_ID} -gt 0 ]; then
    echo Linking ${SLURM_FILE}
    SLURM_FILE=${JOB_DIR}/slurm-${JOB_ID}.out
    # Try a few times to find the file (to let file systems sync)
    for i in 1 2 3 4 5; do
        if [ -f ${SLURM_FILE} ]; then
            break;
        fi
        echo Waiting for the slurm file: ${SLURM_FILE}
        sleep 1;
    done
    # Make a hard or soft link between the slurm file and the "safe" location.
    if [ -f ${SLURM_FILE} ]; then
        echo Check if slurm file and output directory on on the same device.
        if [ $(stat -c "%d" ${SLURM_FILE}) == $(stat -c "%d" ${OUTPUT_DIR}) ]; then
            ln  ${SLURM_FILE} ${OUTPUT_DIR}/slurm-${JOB_ID}.out
        else
            ln -s ${SLURM_FILE} ${OUTPUT_DIR}/slurm-${JOB_ID}.out
        fi
    else
        echo Slurm file not found
    fi
fi

echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
echo Using ${GUNDAM_FITTER}
echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# DUNE configs expect to be run in the GUNDAM_CONFIG
cd ${GUNDAM_CONFIG}

# Try to configure NuOscillator.  The oscillator must be installed in
# ${GUNDAM_CONFIG}
export NUOSCILLATOR_ROOT=""
if [ ${#NUOSCILLATOR_ROOT} == 0 ]; then
    source ./gundamOscAnaTools/resources/TabulateNuOscillator/build-x86_64/bin/setup.NuOscillator.sh
else
    if [ -f ${NUOSCILLATOR_ROOT}/setup.sh ]; then
        source ${NUOSCILLATOR_ROOT}/bin/setup.NuOscillator.sh
    fi
fi
if [ ${#NUOSCILLATOR_ROOT} -gt 0 ]; then
    echo NUOSCILLATOR_ROOT: ${NUOSCILLATOR_ROOT}
else
    echo NUOSCILLATOR NOT CONFIGURED
    exit 1
fi

# Show the GUNDAM command that will be run, and then run!
which ${GUNDAM_FITTER}
echo ${GUNDAM_CONTINUE} \
     ${NEWCHAIN} ${OUTPUT_DIR}/${JOB_BASE}.root -- \
     ${PREFIX_COMMAND} \
     ${GUNDAM_FITTER} ${GUNDAM_OPTIONS} \
     -c ${CONFIG_FILE} ${CONFIG_OVERRIDE} \
     -O /fitterEngineConfig/minimizerConfig/adaptiveRestore=:INPUT: \
     -o :OUTPUT:

echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
echo START $(date)
echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
${GUNDAM_CONTINUE} \
    ${NEWCHAIN} ${OUTPUT_DIR}/${JOB_BASE}.root -- \
     ${PREFIX_COMMAND} \
     ${GUNDAM_FITTER} ${GUNDAM_OPTIONS} \
     -c ${CONFIG_FILE} ${CONFIG_OVERRIDE} \
     -O /fitterEngineConfig/minimizerConfig/adaptiveRestore=:INPUT: \
     -o :OUTPUT: \
      |& tee ${OUTPUT_LOG}
echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
echo FINISH $(date)
echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
