
############################################################
# This is the Dockerfile to build a machine with a bare-   #
# bones installation of the latest FSL (6.0).              #
############################################################

# This docker file is from:
# https://github.com/cbinyu/fsl6-core/blob/master/Dockerfile#
# there are a few lines modified here:
#   - removed line 44 in repo (would come after line 60 here)
#   - line 171-173 in repo (lines 188 to 190 here): changed {FSLDIR}/fslpython/lib/python3.8 to {FSLDIR}/fslpython/lib/python3.9
#   - disabled line 171 in repo (line 180 here)
#   - line 146 in repo (163/164 here), ${FSL_PYTHON}/share/jupyter/nbextensions/plotlywidget does not exist anymore (FSL update?). It's now
#     "${FSL_PYTHON}/share/jupyter/nbextensions/jupyterlab-plotly".  ALso has to be renamed to
#     "${FSL_PYTHON}/share/jupyter/nbextensions/jupyterlab_plotly" to match its "mirroring" library in
#     ${FSL_PYTHON}/lib/python3.7/site-packages/$(basename ${l})/nbextension/
#   - line 147 in repo (line 164 here), "${FSL_PYTHON}/lib/python3.7/site-packages/$(basename ${l})/static/" no longer exists,
#     now it's ${FSL_PYTHON}/lib/python3.7/site-packages/$(basename ${l})/nbextension/




###   Start by creating a "builder"   ###

ARG DEBIAN_VERSION=buster
ARG BASE_PYTHON_VERSION=3.9
# (don't use simply PYTHON_VERSION bc. it's an env variable)
ARG FSL_VERSION=6.0.4

# Use an official Python runtime as a parent image
FROM python:${BASE_PYTHON_VERSION}-slim-${DEBIAN_VERSION} as builder

## install:
# -curl (to get the FSL distribution)
# -libquadmath0 (needed to run many FSL commands )
# -bc
# -dc
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    libquadmath0 \
    bc \
    dc \
  && apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y


# Specify where to install packages:
ENV INSTALL_FOLDER=/usr/local/


###   Install FSL   ###

# The following gives you a clean install of FSL to run in a CLI

# install FSL:
# "fslinstaller.py" only works for python 2.X.
# We exclude atlases, etc, and gpu stuff (this image
#   does not have CUDA):
# This makes the BASE_PYTHON_VERSION available inside this stage
ARG FSL_VERSION
RUN curl -sSL https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-${FSL_VERSION}-centos7_64.tar.gz | tar xz -C ${INSTALL_FOLDER} \
    --exclude='fsl/data/first' \
    --exclude='fsl/data/atlases' \
    --exclude='fsl/data/possum' \
    --exclude='fsl/src' \
    --exclude='fsl/extras/src' \
    --exclude='fsl/bin/fslview*' \
    --exclude='fsl/bin/FSLeyes' \
    --exclude='fsl/bin/*_gpu*' \
    --exclude='fsl/bin/*_cuda*'
#    # Note: ${INSTALL_FOLDER}/fsl/data/standard is needed for functional processing

# Configure environment
ENV FSLDIR=${INSTALL_FOLDER}/fsl/ \
    FSLOUTPUTTYPE=NIFTI_GZ
# (Note: the following cannot be included in the same one-line with
#        the above, since it depends on the previous variables)
ENV FSL_PYTHON=${FSLDIR}/fslpython/envs/fslpython \
    PATH=${FSLDIR}/bin:$PATH \
    LD_LIBRARY_PATH=${FSLDIR}:${LD_LIBRARY_PATH}

# Install fslpython
# (Potentially, we could also not install "vtk")
RUN sed -i -e "/fsleyes/d" -e "/wxpython/d" ${FSLDIR}/etc/fslconf/fslpython_environment.yml && \
    sed -i -e "s/repo.continuum.io/repo.anaconda.com/" ${FSLDIR}/etc/fslconf/fslpython_install.sh && \
    ${FSLDIR}/etc/fslconf/fslpython_install.sh && \
    find ${FSL_PYTHON}/lib/python3.7/site-packages/ -type d \( \
        -name "tests" \
	-o -name "test_files" \
	-o -name "test_data" \
	-o -name "sample_data" \
    \) -print0 | xargs -0 rm -r && \
    for pkg in botocore pylint awscli jedi PyQt5 skimage/data tvtk; do \
      rm -fr ${FSL_PYTHON}/lib/python3.7/site-packages/$pkg; \
    done && \
    rm -r ${FSLDIR}/fslpython/pkgs/* && \
    for d in example resources/testimage resources/fsl; do \
      rm -r ${FSL_PYTHON}/lib/python3.7/site-packages/tirl/share/$d; \
    done && \
    rm -r ${FSL_PYTHON}/bin/pandoc* \
          ${FSL_PYTHON}/bin/qmake && \
    rm -r ${FSL_PYTHON}/include/qt \
          ${FSL_PYTHON}/include/vtk* && \
    for d in doc qt/3rd_party_licenses gir-1.0; do \
      rm -r ${FSL_PYTHON}/share/$d; \
    done && \
    rm -r ${FSL_PYTHON}/translations/qt* && \
    for t in imcp imglob immv; do \
      ln -s ${FSL_PYTHON}/bin/${t} ${FSLDIR}/bin/ ; \
    done && \
    ${FSLDIR}/fslpython/bin/conda clean --all

RUN rm -r ${FSL_PYTHON}/resources/qtwebengine* \
          ${FSL_PYTHON}/conda-meta/vtk* \
          ${FSL_PYTHON}/lib/libQt5* \
          ${FSL_PYTHON}/lib/cmake \
          ${FSL_PYTHON}/lib/libavcodec.a

# FSL has many OpenBLAS, OSMesa, etc. libraries that are identical.
# We'll link them. Because Docker doesn't reduce the file size when you
# do a COPY --from=, I'll write a script with the linking process which
# we'll run at the Application stage. (In the first line, use single
# quotes so that the shell doesn't execute "!"):
RUN echo '#!/bin/bash' > /create_links.sh && \
  # extend globbing: \
  bash -O extglob -c ' \
    for l in ${FSLDIR}/lib/libopenblas*(64|64_|o|p).so; do \
      # if they are the same, delete and save command to link: \
      diff ${l} ${l}.0 \
        && rm ${l} \
        && echo "ln -s ./$(basename ${l}).0 ${l}" >> /create_links.sh ; \
      diff ${l}.0 ${l%.so}-r0.3.3.so \
        && rm ${l}.0 \
        && echo "ln -s ./$(basename ${l%.so})-r0.3.3.so ${l}.0" >> /create_links.sh ; \
    done && \
    for l in ${FSLDIR}/lib/libOSMesa*(16|32).so ${FSLDIR}/lib/libQVTK.so; do \
      fullVersion=$(ls ${l}.?.?.*); \
      minVersion=${fullVersion%.*}; \
      majVersion=${minVersion%.*}; \
      # if there is a major/minor version, that's the version to use: \
      [ -f ${minVersion} ] && version=${minVersion}; \
      [ -f ${majVersion} ] && version=${majVersion}; \
      if [ X$version != X ]; then \
        # if they are the same, delete and create link: \
        diff ${l} ${version} \
          && rm ${l} \
          && echo "ln -s ./$(basename ${version}) ${l}" >> /create_links.sh ; \
        diff ${version} ${fullVersion} \
          && rm ${version} \
          && echo "ln -s ./$(basename ${fullVersion}) ${version}" >> /create_links.sh ; \
      fi \
    done && \
    for l in ${FSLDIR}/lib/libgfortran.so.?; do \
      diff ${l} ${l}.0.0 \
        && rm ${l} \
        && echo "ln -s ./$(basename ${l}).0.0 ${l}" >> /create_links.sh ; \
    done && \
    for l in ${FSL_PYTHON}/lib/libclang.so; do \
      diff ${l} ${l}.9 \
        && rm ${l} \
        && echo "ln -s ./$(basename ${l}).9 ${l}" >> /create_links.sh ; \
    done && \
    mv ${FSL_PYTHON}/share/jupyter/nbextensions/jupyterlab-plotly ${FSL_PYTHON}/share/jupyter/nbextensions/jupyterlab_plotly && \
    for l in ${FSL_PYTHON}/share/jupyter/nbextensions/jupyterlab_plotly; do \
      diff ${l} ${FSL_PYTHON}/lib/python3.7/site-packages/$(basename ${l})/nbextension/ \
        && rm -r ${l} \
        && echo "ln -s ${FSL_PYTHON}/lib/python3.7/site-packages/$(basename ${l})/nbextension ${l}" >> /create_links.sh ; \
    done && \
    for static_l in ${FSLDIR}/extras/include/boost/bin.v2/libs/*/build/gcc-4.8.5/release/link-static/threading-multi/*.[ao] ${FSLDIR}/extras/include/boost/bin.v2/libs/log/build/gcc-4.8.5/release/link-static/log-api-unix/threading-multi/libboost_log*.a; do \
      l=${FSLDIR}/extras/lib/$(basename ${static_l}); \
      [ -f $l ] && diff ${l} ${static_l} \
        && rm -r ${l} \
        && echo "ln -s ${static_l} ${l}" >> /create_links.sh ; \
    done && \
    for r in ${FSLDIR}/data/xtract_data/standard/F99/surf/rh*; do \
      diff ${r} ${r/rh./R.} \
        && rm -r ${r} \
        && echo "ln -s ${r/rh./R.} ${r}" >> /create_links.sh ; \
    done && \
    for l in ${FSLDIR}/data/xtract_data/standard/F99/surf/lh*; do \
      diff ${l} ${l/lh./L.} \
        && rm -r ${l} \
        && echo "ln -s ${l/lh./L.} ${l}" >> /create_links.sh ; \
    done && \
    diff ${FSL_PYTHON}/share/jupyter/nbextensions/jupyter-js-widgets \
        ${FSL_PYTHON}/lib/python3.7/site-packages/widgetsnbextension/static \
      && rm -r ${FSL_PYTHON}/share/jupyter/nbextensions/jupyter-js-widgets \
      && echo "ln -s ${FSL_PYTHON}/lib/python3.7/site-packages/widgetsnbextension/static ${FSL_PYTHON}/share/jupyter/nbextensions/jupyter-js-widgets" >> /create_links.sh && \
    #diff ${FSL_PYTHON}/lib/python3.7/ensurepip/_bundled ${FSLDIR}/fslpython/lib/python3.9/ensurepip/_bundled \
      rm -r ${FSLDIR}/fslpython/lib/python3.9/ensurepip/_bundled \
      && echo "ln -s ${FSL_PYTHON}/lib/python3.7/ensurepip/_bundled ${FSLDIR}/fslpython/lib/python3.9/ensurepip/_bundled" >> /create_links.sh && \
    rm -r ${FSLDIR}/lib/libbedpostx_cuda.so && \
    rm -r ${FSLDIR}/lib/libvtk* ${FSLDIR}/lib/libqwt.* ${FSLDIR}/lib/libfslvtkio.*\
  '     # end of "bash -0 extglob..."
#############
###  Now, get a new machine with only the essentials  ###
FROM python:${BASE_PYTHON_VERSION}-slim-${DEBIAN_VERSION} as Application
# This makes the BASE_PYTHON_VERSION available inside this stage
ARG BASE_PYTHON_VERSION
ENV PYTHON_LIB_PATH=/usr/local/lib/python${BASE_PYTHON_VERSION}
ENV FSLDIR=/usr/local/fsl/ \
    FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=${FSLDIR}/bin:$PATH \
    LD_LIBRARY_PATH=${FSLDIR}:${LD_LIBRARY_PATH}
# Copy system binaries and libraries:
COPY --from=builder ./lib/x86_64-linux-gnu/     /lib/x86_64-linux-gnu/
COPY --from=builder ./usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/
COPY --from=builder ./usr/bin/                  /usr/bin/
COPY --from=builder ./usr/local/bin/           /usr/local/bin/
# COPY --from=builder ./${PYTHON_LIB_PATH}/site-packages/      ${PYTHON_LIB_PATH}/site-packages/
# Copy $FSLDIR:
COPY --from=builder ./${FSLDIR}/  ${FSLDIR}/
# Create the links:
COPY --from=builder ./create_links.sh  /create_links.sh
RUN chmod u+x /create_links.sh && \
    /create_links.sh

#RUN curl https://packages.bic.mni.mcgill.ca/mni-models/icbm152/mni_icbm152_nl_VI_nifti.zip --output /tmp/mni.zip && \
#    unzip /tmp/mni.zip -d /${FSLDIR}/data/standard && \
#    rm /tmp/mni.zip && \
#    mv ${FSLDIR}/data/standard/icbm_avg_152_t1_tal_nlin_symmetric_VI.nii
#RUN curl -#L  $URL | bsdtar -xf- -C /opt/

# Overwrite the entrypoint of the base Docker image (python)


MAINTAINER Flywheel <support@flywheel.io>
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update \
    && apt-get install -y \
        zip \
        jq \
        curl \
        bsdtar \
        python-pip


# Download/Install webpage2html
ENV COMMIT=7a72d6eb70fdc821f3bc064636ee48eed14dd76a
ENV URL=https://github.com/zTrix/webpage2html/archive/$COMMIT.zip
RUN curl -#L  $URL | bsdtar -xf- -C /opt/
WORKDIR /opt
RUN mv webpage2html-$COMMIT webpage2html
RUN pip install -r webpage2html/requirements.txt
#RUN pip install webpage2html

# Make directory for flywheel spec (v0)
ENV FLYWHEEL /flywheel/v0
RUN mkdir -p ${FLYWHEEL}
COPY run ${FLYWHEEL}/run
COPY manifest.json ${FLYWHEEL}/manifest.json
COPY template.fsf ${FLYWHEEL}/


# Configure entrypoint
# ENTRYPOINT ["/bin/bash"]
ENTRYPOINT ["/flywheel/v0/run"]