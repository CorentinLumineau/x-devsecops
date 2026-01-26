---
title: Secure File Upload Reference
category: security
type: reference
version: "1.0.0"
---

# Secure File Upload Validation

> Part of the security/input-validation knowledge skill

## Overview

File upload functionality is a common attack vector for malware distribution, remote code execution, and denial of service. This reference covers comprehensive validation patterns for secure file handling.

## 80/20 Quick Reference

**File upload security layers:**

| Layer | Defense | Purpose |
|-------|---------|---------|
| 1 | Extension whitelist | Block obviously dangerous files |
| 2 | MIME type validation | Verify content matches claimed type |
| 3 | Magic bytes check | Detect disguised files |
| 4 | Size limits | Prevent DoS |
| 5 | Filename sanitization | Prevent path traversal |
| 6 | Isolated storage | Prevent execution |

**High-risk file types to block:**
`.exe`, `.dll`, `.bat`, `.cmd`, `.ps1`, `.sh`, `.php`, `.jsp`, `.asp`, `.aspx`, `.cgi`, `.pl`, `.py`, `.rb`, `.jar`, `.war`, `.htaccess`, `.svg` (contains JS)

## Patterns

### Pattern 1: Extension and MIME Type Validation

**When to Use**: All file uploads

**Implementation**:
```typescript
import multer from 'multer';
import path from 'path';

// Allowed file types configuration
const ALLOWED_FILE_TYPES = {
  images: {
    extensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
  },
  documents: {
    extensions: ['.pdf', '.doc', '.docx', '.xls', '.xlsx'],
    mimeTypes: [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]
  }
};

// File filter function
function createFileFilter(allowedTypes: typeof ALLOWED_FILE_TYPES.images) {
  return (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    // Check extension
    const ext = path.extname(file.originalname).toLowerCase();
    if (!allowedTypes.extensions.includes(ext)) {
      return cb(new Error(`File extension ${ext} not allowed`));
    }

    // Check MIME type
    if (!allowedTypes.mimeTypes.includes(file.mimetype)) {
      return cb(new Error(`MIME type ${file.mimetype} not allowed`));
    }

    cb(null, true);
  };
}

// Multer configuration
const uploadImage = multer({
  storage: multer.memoryStorage(),  // Process in memory first
  limits: {
    fileSize: 5 * 1024 * 1024,  // 5MB
    files: 1
  },
  fileFilter: createFileFilter(ALLOWED_FILE_TYPES.images)
});

// Usage
app.post('/upload/avatar', uploadImage.single('avatar'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  // Further validation and processing
});
```

**Anti-Pattern**: Only checking extension
```typescript
// VULNERABLE - MIME type can be spoofed
if (file.originalname.endsWith('.jpg')) {
  // Accept file
}
```

### Pattern 2: Magic Bytes Verification

**When to Use**: Verifying file content matches claimed type

**Implementation**:
```typescript
import fileType from 'file-type';

// Magic bytes signatures
const FILE_SIGNATURES: Record<string, { magic: Buffer; extensions: string[] }> = {
  jpeg: { magic: Buffer.from([0xFF, 0xD8, 0xFF]), extensions: ['.jpg', '.jpeg'] },
  png: { magic: Buffer.from([0x89, 0x50, 0x4E, 0x47]), extensions: ['.png'] },
  gif: { magic: Buffer.from([0x47, 0x49, 0x46]), extensions: ['.gif'] },
  pdf: { magic: Buffer.from([0x25, 0x50, 0x44, 0x46]), extensions: ['.pdf'] },
  zip: { magic: Buffer.from([0x50, 0x4B, 0x03, 0x04]), extensions: ['.zip', '.docx', '.xlsx'] }
};

// Verify file content
async function verifyFileType(buffer: Buffer, claimedExtension: string): Promise<boolean> {
  // Use file-type library for robust detection
  const detected = await fileType.fromBuffer(buffer);

  if (!detected) {
    // Could be text file - check for scripts
    const content = buffer.toString('utf8', 0, 1000);
    if (/<script|<\?php|<%|#!/i.test(content)) {
      return false;  // Script content detected
    }
    return true;  // Assume plain text is okay
  }

  // Check if detected type matches claimed extension
  const allowedExtensions = FILE_SIGNATURES[detected.ext]?.extensions || [`.${detected.ext}`];
  return allowedExtensions.includes(claimedExtension.toLowerCase());
}

// Middleware for magic bytes validation
async function validateFileContent(req: Express.Request, res: Express.Response, next: Express.NextFunction) {
  if (!req.file) return next();

  const ext = path.extname(req.file.originalname).toLowerCase();
  const isValid = await verifyFileType(req.file.buffer, ext);

  if (!isValid) {
    return res.status(400).json({
      error: 'File content does not match extension'
    });
  }

  next();
}

// Usage
app.post('/upload',
  uploadImage.single('file'),
  validateFileContent,
  processUpload
);
```

### Pattern 3: Filename Sanitization

**When to Use**: Storing files with user-provided names

**Implementation**:
```typescript
import path from 'path';
import crypto from 'crypto';

// Sanitize filename - remove dangerous characters
function sanitizeFilename(filename: string): string {
  // Remove path components
  const basename = path.basename(filename);

  // Remove null bytes and control characters
  let sanitized = basename.replace(/[\x00-\x1f\x80-\x9f]/g, '');

  // Remove path traversal attempts
  sanitized = sanitized.replace(/\.\./g, '');

  // Allow only alphanumeric, dash, underscore, dot
  sanitized = sanitized.replace(/[^a-zA-Z0-9._-]/g, '_');

  // Limit length
  if (sanitized.length > 200) {
    const ext = path.extname(sanitized);
    sanitized = sanitized.substring(0, 200 - ext.length) + ext;
  }

  // Ensure not empty
  if (!sanitized || sanitized === '.') {
    sanitized = 'unnamed';
  }

  return sanitized;
}

// Generate unique filename (preferred for storage)
function generateSecureFilename(originalName: string): string {
  const ext = path.extname(originalName).toLowerCase();
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.pdf'];

  // Validate extension
  if (!allowedExtensions.includes(ext)) {
    throw new Error('Invalid file extension');
  }

  // Generate random filename
  const randomPart = crypto.randomBytes(16).toString('hex');
  const timestamp = Date.now();

  return `${timestamp}-${randomPart}${ext}`;
}

// Prevent path traversal in storage
function getSecureStoragePath(baseDir: string, filename: string): string {
  const sanitized = sanitizeFilename(filename);
  const fullPath = path.join(baseDir, sanitized);

  // Verify path is still within base directory
  const resolved = path.resolve(fullPath);
  const base = path.resolve(baseDir);

  if (!resolved.startsWith(base + path.sep)) {
    throw new Error('Path traversal detected');
  }

  return resolved;
}
```

### Pattern 4: Image Processing and Stripping

**When to Use**: User-uploaded images that will be displayed

**Implementation**:
```typescript
import sharp from 'sharp';

// Process and sanitize image
async function processImage(buffer: Buffer): Promise<Buffer> {
  return sharp(buffer)
    // Resize to maximum dimensions
    .resize(2000, 2000, {
      fit: 'inside',
      withoutEnlargement: true
    })
    // Convert to safe format (strips metadata, potential exploits)
    .jpeg({
      quality: 85,
      mozjpeg: true
    })
    // Remove EXIF data (privacy and potential XSS in EXIF)
    .rotate()  // Auto-rotate based on EXIF, then strip
    .toBuffer();
}

// Process with format preservation
async function processImagePreserveFormat(
  buffer: Buffer,
  mimeType: string
): Promise<{ buffer: Buffer; mimeType: string }> {
  let processor = sharp(buffer)
    .resize(2000, 2000, { fit: 'inside', withoutEnlargement: true })
    .rotate();

  switch (mimeType) {
    case 'image/png':
      return {
        buffer: await processor.png({ quality: 85 }).toBuffer(),
        mimeType: 'image/png'
      };
    case 'image/gif':
      // GIF processing loses animation - consider keeping as-is or converting
      return {
        buffer: await processor.gif().toBuffer(),
        mimeType: 'image/gif'
      };
    case 'image/webp':
      return {
        buffer: await processor.webp({ quality: 85 }).toBuffer(),
        mimeType: 'image/webp'
      };
    default:
      return {
        buffer: await processor.jpeg({ quality: 85 }).toBuffer(),
        mimeType: 'image/jpeg'
      };
  }
}

// Scan for embedded scripts in SVG
function validateSvg(content: string): boolean {
  const dangerous = [
    /<script/i,
    /javascript:/i,
    /on\w+\s*=/i,  // Event handlers: onclick, onerror, etc.
    /<foreignObject/i,
    /<embed/i,
    /<iframe/i
  ];

  return !dangerous.some(pattern => pattern.test(content));
}
```

### Pattern 5: Secure Storage Configuration

**When to Use**: Storing uploaded files

**Implementation**:
```typescript
import AWS from 'aws-sdk';
import { v4 as uuidv4 } from 'uuid';

// S3 configuration for secure uploads
const s3 = new AWS.S3({
  region: process.env.AWS_REGION
});

async function uploadToS3(
  buffer: Buffer,
  originalName: string,
  mimeType: string
): Promise<string> {
  const ext = path.extname(originalName).toLowerCase();
  const key = `uploads/${uuidv4()}${ext}`;

  await s3.putObject({
    Bucket: process.env.S3_BUCKET!,
    Key: key,
    Body: buffer,
    ContentType: mimeType,
    // Prevent execution
    ContentDisposition: 'attachment',
    // Server-side encryption
    ServerSideEncryption: 'AES256',
    // Access control
    ACL: 'private'
  }).promise();

  return key;
}

// Generate signed URL for access
async function getSignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
  return s3.getSignedUrlPromise('getObject', {
    Bucket: process.env.S3_BUCKET!,
    Key: key,
    Expires: expiresIn,
    // Force download (prevent execution in browser)
    ResponseContentDisposition: 'attachment'
  });
}

// Local storage with security measures
import fs from 'fs/promises';

const UPLOAD_DIR = '/var/uploads';  // Outside web root!

async function saveToLocal(
  buffer: Buffer,
  originalName: string
): Promise<string> {
  const filename = generateSecureFilename(originalName);
  const filepath = path.join(UPLOAD_DIR, filename);

  await fs.writeFile(filepath, buffer, { mode: 0o644 });

  return filename;
}
```

### Pattern 6: Virus/Malware Scanning

**When to Use**: File uploads from untrusted sources

**Implementation**:
```typescript
import ClamScan from 'clamscan';

// Initialize ClamAV scanner
const clamScan = new ClamScan({
  clamdscan: {
    socket: '/var/run/clamav/clamd.ctl',
    timeout: 60000,
    localFallback: true
  },
  preference: 'clamdscan'
});

// Scan file for malware
async function scanForMalware(buffer: Buffer): Promise<{ clean: boolean; viruses?: string[] }> {
  try {
    const { isInfected, viruses } = await clamScan.scanBuffer(buffer);

    return {
      clean: !isInfected,
      viruses: isInfected ? viruses : undefined
    };
  } catch (error) {
    // Log error but don't fail - scanner might be unavailable
    console.error('Virus scan failed:', error);
    // Decide policy: reject file or accept with warning
    throw new Error('Virus scan unavailable');
  }
}

// Integration in upload flow
app.post('/upload',
  uploadMiddleware.single('file'),
  async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'No file' });
    }

    // Scan for malware
    const scanResult = await scanForMalware(req.file.buffer);
    if (!scanResult.clean) {
      return res.status(400).json({
        error: 'Malware detected',
        details: scanResult.viruses
      });
    }

    // Continue with processing
  }
);
```

## Checklist

- [ ] File extension whitelist enforced
- [ ] MIME type validated against whitelist
- [ ] Magic bytes verified to match extension
- [ ] File size limits configured
- [ ] Filename sanitized (no path traversal)
- [ ] Files stored outside web root
- [ ] Content-Disposition: attachment for downloads
- [ ] Images re-processed to strip metadata
- [ ] SVG files validated or converted
- [ ] Virus scanning for high-risk uploads
- [ ] Rate limiting on upload endpoints

## References

- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)
- [CWE-434: Unrestricted Upload](https://cwe.mitre.org/data/definitions/434.html)
- [File Signatures (Magic Bytes)](https://en.wikipedia.org/wiki/List_of_file_signatures)
- [Sharp Image Processing](https://sharp.pixelplumbing.com/)
