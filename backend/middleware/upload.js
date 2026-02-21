const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Keep uploads under backend/uploads so express static path always matches.
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination(req, file, cb) {
    cb(null, uploadDir);
  },
  filename(req, file, cb) {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const allowedExtensions = new Set([
  '.jpeg',
  '.jpg',
  '.png',
  '.gif',
  '.webp',
  '.heic',
  '.heif',
  '.pdf',
  '.doc',
  '.docx',
  '.txt',
]);

const allowedMimePrefixes = ['image/'];
const allowedMimeExact = new Set([
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
]);

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  const mime = (file.mimetype || '').toLowerCase();

  const extAllowed = allowedExtensions.has(ext);
  const mimeAllowed =
    allowedMimePrefixes.some((prefix) => mime.startsWith(prefix)) ||
    allowedMimeExact.has(mime);

  if (extAllowed && mimeAllowed) {
    cb(null, true);
    return;
  }

  const error = new Error('Invalid file type. Allowed: images, PDF, DOC, DOCX, TXT.');
  error.statusCode = 400;
  cb(error);
};

const upload = multer({
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter,
});

module.exports = upload;
