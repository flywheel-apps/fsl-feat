# Create a base docker container that will run FSL's FEAT
#
#

FROM neurodebian:trusty

MAINTAINER Flywheel <support@flywheel.io>


# Install dependencies
RUN echo deb http://neurodeb.pirsquared.org data main contrib non-free >> /etc/apt/sources.list.d/neurodebian.sources.list
RUN echo deb http://neurodeb.pirsquared.org trusty main contrib non-free >> /etc/apt/sources.list.d/neurodebian.sources.list
RUN apt-get update \
    && apt-get install -y \
        fsl-5.0-complete \
        zip \
        jq

# Make directory for flywheel spec (v0)
ENV FLYWHEEL /flywheel/v0
RUN mkdir -p ${FLYWHEEL}
COPY run ${FLYWHEEL}/run
COPY manifest.json ${FLYWHEEL}/manifest.json
COPY template.fsf ${FLYWHEEL}

# Configure entrypoint
ENTRYPOINT ["/flywheel/v0/run"]
