# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=a2gent-brute:latest
FROM ${BASE_IMAGE}

# WHY: Rebel Art uses deterministic Blender Python generators and validates
# textures with Pillow. Keep these heavyweight native dependencies out of the
# default Brute image so non-art agents remain small and quick to rebuild.
USER root
RUN apk add --no-cache \
    blender \
    py3-numpy \
    py3-pillow
USER aagent
