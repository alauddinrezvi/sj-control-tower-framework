Based on the two docs, here is what you can expect.  
Sources reviewed: Knowledgebase Implementation Guide and Knowledge Base Embedding Strategy

## **1\. User Side — UI Perspective**

### Knowledge Base Main Page

* User will see a **Knowledge Base / Files page**.  
* The page will show:  
  * Folders.  
  * Files.  
  * Root-level files.  
  * Files inside selected folders.  
* User can switch between:  
  * Grid view.  
  * List view.  
* User will see loading skeletons while folders/files are loading.

### Folder Management

* User can create a new folder.  
* User can edit folder details.  
* User can rename folders.  
* User can choose folder color.  
* User can delete folders.  
* User can open a folder and see files inside it.  
* Breadcrumb will show navigation like:  
  * Home → Selected Folder.

### File Upload

* User can upload one or multiple files.  
* Files can be uploaded:  
  * In the root.  
  * Inside a selected folder.  
* Upload should support progress feedback.  
* User can upload up to 20 files at once.  
* Each file limit is expected to be 50 MB by default.  
* User can decide whether a file is:  
  * Public.  
  * Shared.  
  * Private.

### File Actions

* User can perform actions like:  
  * Rename file.  
  * Move file to another folder.  
  * Star/unstar file.  
  * Delete file.  
  * Download file.  
  * Stream/preview file.  
  * Manage access.

### Search

* User can search within visible folders and files.  
* Search works based on current location.  
* Example:  
  * If user is in root, search filters root folders/files.  
  * If user is inside a folder, search filters files inside that folder.

### Duplicate Upload Handling

* If user uploads a file with the same name in the same folder, UI should detect it.  
* User will get options:  
  * Overwrite existing file.  
  * Save as a new version.  
  * Skip upload.  
* Example:  
  * `document.pdf`  
  * `document (1).pdf`

### Sharing UI

* User can share folders or files with other users.  
* Sharing can include permissions:  
  * Read.  
  * Write.  
* User can see items shared with them.  
* Shared files/folders should show a **“Shared with me”** badge.  
* User should see owner details when available:  
  * Owner name.  
  * Owner email.  
  * Owner avatar.

### Permission-Based UI

* Owner-only actions should be visible/enabled only for owners.  
* These include:  
  * Edit.  
  * Delete.  
  * Move.  
  * Manage access.  
* Users with write permission may update shared records.  
* Users with read permission should only view/access.

### Storage Status UI

* Files may come from:  
  * Local storage.  
  * S3 storage.  
* If the file belongs to an inactive storage backend, it should look visually muted.  
* Some actions should be disabled for files from inactive storage.

### Keyboard Shortcuts

* `Ctrl + N` → Create folder.  
* `Ctrl + U` → Upload files.  
* `Ctrl + F` → Focus search.  
* `Shift + ?` → Show keyboard shortcuts.  
* `Escape` → Close dialogs.

### RAG / AI Agent UI Expectations

* User uploads files to Knowledge Base first.  
* Later, user can attach selected knowledge files to an AI agent or project.  
* User should select files by stable file ID.  
* User should not need to re-upload the same file for each agent.  
* If embeddings are generated lazily, user may see:  
  * Indexing.  
  * Processing.  
  * Completed.  
  * Failed.

## **2\. Technical Backend Logics**

### Core Backend Module

* Backend should expose `/api/knowledge` routes.  
* Backend should have separate layers:  
  * Routes.  
  * Controllers.  
  * Services.  
  * Repositories.  
  * Validation middleware.  
  * Error constants.

### Database Tables

* Main tables:  
  * `folders`.  
  * `files`.  
* Recommended database:  
  * Supabase/Postgres.  
* Legacy Mongoose models may exist, but active design uses Supabase.

### Folder Table Logic

* Each folder stores:  
  * Folder ID.  
  * User ID.  
  * Name.  
  * Color.  
  * Public/private status.  
  * Shared status.  
  * Size.  
  * File count.  
  * Shared users.  
  * Created/updated timestamps.  
  * Soft delete timestamp.

### File Table Logic

* Each file stores:  
  * File ID.  
  * User ID.  
  * Folder ID.  
  * File name.  
  * Original name.  
  * Size.  
  * Type.  
  * MIME type.  
  * Path.  
  * URL.  
  * S3 key.  
  * Storage type.  
  * Starred status.  
  * Public/shared status.  
  * Metadata.  
  * OpenAI/RAG metadata.  
  * Shared users.  
  * Created/updated timestamps.  
  * Soft delete timestamp.

### Authentication Logic

* Every read/write should use `req.user.id`.  
* Backend must only return records that the current user owns or has shared access to.  
* User identity should control:  
  * Folder listing.  
  * File listing.  
  * Upload.  
  * Delete.  
  * Sharing.  
  * RAG file access.

### Folder API Logic

Expected endpoints:

* `GET /api/knowledge/folders`  
* `GET /api/knowledge/folders/:id`  
* `POST /api/knowledge/folders`  
* `PUT /api/knowledge/folders/:id`  
* `DELETE /api/knowledge/folders/:id`  
* `GET /api/knowledge/folders/:folderId/files`

### File API Logic

Expected endpoints:

* `GET /api/knowledge/files`  
* `GET /api/knowledge/files/statistics`  
* `GET /api/knowledge/files/:id`  
* `POST /api/knowledge/files`  
* `GET /api/knowledge/files/:id/download`  
* `GET /api/knowledge/files/:id/stream`  
* `PUT /api/knowledge/files/:id`  
* `DELETE /api/knowledge/files/:id`  
* `POST /api/knowledge/files/bulk-delete`  
* `POST /api/knowledge/files/bulk-toggle-public`  
* `POST /api/knowledge/files/bulk-toggle-shared`

### Upload Logic

* Upload should use `multipart/form-data`.  
* Field name should be `files`.  
* Backend should use `multer.array('files', 20)`.  
* Default max size should be 50 MB per file.  
* Upload request should include:  
  * Files.  
  * Folder ID.  
  * Public status.  
  * Shared status.

### Local Storage Logic

* Local files should be saved under:

uploads/knowledgebase/\<userId\>/\<fileId\>.\<ext\>

* Backend flow:  
  * Upload temporary file.  
  * Create database record.  
  * Rename physical file using generated file ID.  
  * Store final URL in DB.

### S3 Storage Logic

* S3 path should follow:

knowledgebase/\<userId\>/\<fileId\>.\<ext\>

* If `STORAGE_TYPE=s3`, backend should:  
  * Upload file to S3.  
  * Save `s3_key`.  
  * Save S3 URL/path metadata.  
  * Mark `storage_type='s3'`.

### File Type Logic

* Backend should use MIME type as source of truth.  
* File types should map into:  
  * Document.  
  * Image.  
  * Audio.  
  * Video.  
  * Archive.  
  * Code.  
  * Other.

### Listing Logic

* Folder listing should return:  
  * Folders owned by the user.  
  * Folders shared with the user.  
* File listing should return:  
  * Owned files.  
  * Directly shared files.  
  * Files inside folders shared with the user.

### Sharing Logic

* Sharing data is stored in `shared_with` JSONB.  
* Shared user object includes:  
  * User ID.  
  * Name.  
  * Email.  
  * Avatar.  
  * Permission.  
  * Added date.  
  * Excluded status.  
* Folder sharing gives access to files inside the folder.  
* Direct file sharing can override folder-level sharing.

### Delete Logic

* Owner deleting a file/folder should delete or soft-delete the owner record.  
* Shared user deleting a shared item should not delete the actual file.  
* Instead, backend should remove that user from the `shared_with` list.  
* For deleted KB files, backend should also clean up:  
  * S3 object.  
  * Embeddings.  
  * Related references where needed.

### Optimistic UI Support

* Frontend will update UI immediately.  
* Backend must return clean success/error responses.  
* If API fails, frontend should rollback and show toast error.

### Response Shape

* API should return consistent responses:

{ success: true, data: {}, message: "..." }

* Paginated list responses should include:  
  * Page.  
  * Limit.  
  * Total.  
  * Total pages.

### RAG / AI Agent Logic

* Knowledge Base acts as the stable source of files.  
* Agents should reference files by file ID.  
* Backend should not blindly re-upload files for every agent.  
* Typical flow:  
  * User uploads file.  
  * User attaches file ID to agent.  
  * Backend resolves file from DB.  
  * Backend downloads from S3 or reads local path.  
  * Backend parses/chunks file.  
  * Backend creates embeddings.  
  * Backend stores file references on agent/project.

### Embedding Strategy

* Recommended approach is **hybrid lazy embedding**.  
* Default behavior:  
  * Upload file to S3.  
  * Insert file row in Supabase.  
  * Do not embed immediately.  
  * Embed only when file is attached to an agent or user selects “Index for search.”  
* This saves cost because not every uploaded file will be used in RAG.  
* Optional behavior:  
  * Add “Index immediately for search” checkbox during upload.  
  * Auto-index selected folders or file types.

### Embedding Storage Logic

* Raw files should stay in S3.  
* File metadata should stay in Supabase.  
* Embeddings should preferably stay in Supabase pgvector.  
* Agents should use `agent_knowledge_files` to connect agents and files.  
* Embeddings should be reusable by `file_id`.

### Deduplication Logic for Embeddings

* Before embedding, backend should check:  
  * File ID.  
  * Embedding model.  
  * Existing chunks.  
* If fresh embeddings already exist, skip re-embedding.  
* This prevents the same file from being embedded multiple times for different agents.

### File Update / Overwrite Logic

* If a file is overwritten:  
  * Version should be updated.  
  * Old embeddings should be invalidated.  
  * Re-index should happen on next agent attach or explicit indexing request.

### Recommended Technical Direction

* Use S3 for raw file storage.  
* Use Supabase for file/folder metadata.  
* Use Supabase pgvector for embeddings.  
* Use lazy embedding by default.  
* Use stable file IDs across:  
  * Knowledge Base.  
  * AI agents.  
  * Projects.  
  * RAG workflows.

