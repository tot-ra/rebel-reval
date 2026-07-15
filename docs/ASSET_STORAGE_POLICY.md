# Asset Storage Policy

This document defines the storage policy for approved large binary sources in the **Reval Rebel** repository, addressing Git LFS (Large File Storage) and external storage guidelines.

## Tracked Formats

The following binary asset formats are subject to this storage policy:

*   **Audio:** `.wav`, `.ogg`, `.mp3`
*   **Images & Textures:** `.png`, `.jpg`, `.jpeg`, `.psd`, `.kra`
*   **Models & 3D Assets:** `.blend`, `.fbx`, `.glb`, `.gltf`, `.obj`
*   **Fonts:** `.ttf`, `.otf`, `.woff`, `.woff2`
*   **Archives:** `.zip`, `.tar.gz`, `.rar`

*Note: Godot's `*.import` sidecar files are plain text and must remain in standard Git version control, not LFS.*

## Size Threshold

*   **Standard Git:** Any source file **under 10 MB** may be committed directly to the standard Git repository, provided it is an approved runtime asset or necessary source.
*   **Git LFS:** Any binary file **10 MB or larger**, or any file belonging to the tracked formats that is expected to be modified frequently (like `.psd`, `.kra`, `.blend`), must be tracked via Git LFS.
*   **External Storage:** Massive source files (e.g., raw hour-long audio sessions, 4K marketing video renders, or archived bulk assets over 100 MB) should not be tracked in Git LFS to preserve bandwidth. They must be stored in the designated team external drive/cloud storage and referenced in the repository via a documentation link or `assets/SOURCES.csv`.

## Retrieval Process

To retrieve LFS-tracked files after cloning or pulling the repository:

1. Ensure Git LFS is installed on your system (`git lfs install`).
2. Run the following command to download the LFS content:
   ```bash
   git lfs pull
   ```
3. Godot will automatically import these assets upon opening the project or running the headless import command.

## Failure Behavior

If Git LFS fails to fetch an asset, or if external storage is inaccessible:

1. **Missing Files:** The `git lfs pull` command may fail with a bandwidth limit or authentication error. The repository will contain lightweight pointer files instead of the actual binary content.
2. **Godot Import Errors:** Godot will report "Failed to load resource" or missing dependencies in the console for any missing binary file.
3. **Fallback/Placeholders:** If an asset cannot be retrieved:
    * Do not commit the pointer file as a resolution.
    * Use a designated placeholder asset (e.g., a simple magenta texture or empty audio file) temporarily if local development is blocked.
    * Report the LFS fetching error to the repository maintainers.
4. **CI/CD Pipeline:** The CI/CD pipeline must be configured to execute `git lfs pull` before headless import. If LFS retrieval fails, the pipeline should fail fast and output the Git LFS error logs.
