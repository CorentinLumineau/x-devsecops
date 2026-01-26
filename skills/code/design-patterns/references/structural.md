---
title: Structural Design Patterns Reference
category: code
type: reference
version: "1.0.0"
---

# Structural Design Patterns

> Part of the code/design-patterns knowledge skill

## Overview

Structural patterns compose classes and objects to form larger structures while keeping them flexible and efficient. This reference covers Adapter, Decorator, and Facade patterns with practical implementations.

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| Adapter | Make incompatible interfaces work together |
| Decorator | Add responsibilities dynamically |
| Facade | Simplify complex subsystem interface |
| Proxy | Control access to an object |
| Composite | Treat individual objects and compositions uniformly |
| Bridge | Separate abstraction from implementation |

## Patterns

### Pattern 1: Adapter

**When to Use**: Integrating incompatible interfaces or legacy code

**Example**:
```typescript
// Target interface (what our code expects)
interface PaymentProcessor {
  processPayment(amount: number, currency: string): Promise<PaymentResult>;
  refund(transactionId: string, amount: number): Promise<RefundResult>;
  getTransaction(transactionId: string): Promise<Transaction>;
}

interface PaymentResult {
  success: boolean;
  transactionId: string;
  message?: string;
}

// Adaptee (third-party library with different interface)
class StripeAPI {
  async createCharge(params: {
    amount: number;
    currency: string;
    source: string;
  }): Promise<StripeCharge> {
    // Stripe API call
    return { id: 'ch_xxx', status: 'succeeded', amount: params.amount };
  }

  async createRefund(chargeId: string, amount?: number): Promise<StripeRefund> {
    return { id: 'rf_xxx', charge: chargeId, amount };
  }

  async retrieveCharge(chargeId: string): Promise<StripeCharge> {
    return { id: chargeId, status: 'succeeded', amount: 1000 };
  }
}

// Adapter
class StripePaymentAdapter implements PaymentProcessor {
  constructor(
    private stripe: StripeAPI,
    private defaultSource: string
  ) {}

  async processPayment(amount: number, currency: string): Promise<PaymentResult> {
    try {
      const charge = await this.stripe.createCharge({
        amount: Math.round(amount * 100), // Stripe uses cents
        currency: currency.toLowerCase(),
        source: this.defaultSource
      });

      return {
        success: charge.status === 'succeeded',
        transactionId: charge.id,
        message: charge.status
      };
    } catch (error) {
      return {
        success: false,
        transactionId: '',
        message: error.message
      };
    }
  }

  async refund(transactionId: string, amount: number): Promise<RefundResult> {
    const refund = await this.stripe.createRefund(
      transactionId,
      Math.round(amount * 100)
    );

    return {
      success: true,
      refundId: refund.id,
      originalTransactionId: transactionId
    };
  }

  async getTransaction(transactionId: string): Promise<Transaction> {
    const charge = await this.stripe.retrieveCharge(transactionId);

    return {
      id: charge.id,
      amount: charge.amount / 100,
      status: this.mapStatus(charge.status)
    };
  }

  private mapStatus(stripeStatus: string): TransactionStatus {
    const statusMap: Record<string, TransactionStatus> = {
      'succeeded': 'completed',
      'pending': 'pending',
      'failed': 'failed'
    };
    return statusMap[stripeStatus] || 'unknown';
  }
}

// Another adaptee (different payment provider)
class PayPalSDK {
  async capturePayment(orderId: string): Promise<PayPalCapture> {
    return { id: 'CAP-xxx', status: 'COMPLETED' };
  }
}

class PayPalPaymentAdapter implements PaymentProcessor {
  constructor(private paypal: PayPalSDK) {}

  async processPayment(amount: number, currency: string): Promise<PaymentResult> {
    // Adapt PayPal's different flow
    const capture = await this.paypal.capturePayment('order-id');

    return {
      success: capture.status === 'COMPLETED',
      transactionId: capture.id
    };
  }

  // ... other methods
}

// Usage - client code works with any adapter
class CheckoutService {
  constructor(private paymentProcessor: PaymentProcessor) {}

  async checkout(cart: Cart): Promise<OrderResult> {
    const result = await this.paymentProcessor.processPayment(
      cart.total,
      cart.currency
    );

    if (result.success) {
      return { orderId: result.transactionId, status: 'confirmed' };
    }

    throw new PaymentError(result.message);
  }
}

// Inject appropriate adapter
const stripeAdapter = new StripePaymentAdapter(new StripeAPI(), 'src_xxx');
const checkout = new CheckoutService(stripeAdapter);
```

**Anti-Pattern**: Modifying the adaptee class directly instead of creating an adapter.

### Pattern 2: Decorator

**When to Use**: Adding responsibilities to objects dynamically

**Example**:
```typescript
// Component interface
interface DataSource {
  read(): Promise<string>;
  write(data: string): Promise<void>;
}

// Concrete component
class FileDataSource implements DataSource {
  constructor(private filePath: string) {}

  async read(): Promise<string> {
    return fs.promises.readFile(this.filePath, 'utf8');
  }

  async write(data: string): Promise<void> {
    await fs.promises.writeFile(this.filePath, data);
  }
}

// Base decorator
abstract class DataSourceDecorator implements DataSource {
  constructor(protected wrapped: DataSource) {}

  async read(): Promise<string> {
    return this.wrapped.read();
  }

  async write(data: string): Promise<void> {
    await this.wrapped.write(data);
  }
}

// Concrete decorators
class EncryptionDecorator extends DataSourceDecorator {
  constructor(
    wrapped: DataSource,
    private encryptionKey: string
  ) {
    super(wrapped);
  }

  async read(): Promise<string> {
    const encrypted = await super.read();
    return this.decrypt(encrypted);
  }

  async write(data: string): Promise<void> {
    const encrypted = this.encrypt(data);
    await super.write(encrypted);
  }

  private encrypt(data: string): string {
    const cipher = crypto.createCipher('aes-256-cbc', this.encryptionKey);
    return cipher.update(data, 'utf8', 'hex') + cipher.final('hex');
  }

  private decrypt(data: string): string {
    const decipher = crypto.createDecipher('aes-256-cbc', this.encryptionKey);
    return decipher.update(data, 'hex', 'utf8') + decipher.final('utf8');
  }
}

class CompressionDecorator extends DataSourceDecorator {
  async read(): Promise<string> {
    const compressed = await super.read();
    return this.decompress(compressed);
  }

  async write(data: string): Promise<void> {
    const compressed = this.compress(data);
    await super.write(compressed);
  }

  private compress(data: string): string {
    return zlib.gzipSync(data).toString('base64');
  }

  private decompress(data: string): string {
    const buffer = Buffer.from(data, 'base64');
    return zlib.gunzipSync(buffer).toString('utf8');
  }
}

class LoggingDecorator extends DataSourceDecorator {
  constructor(
    wrapped: DataSource,
    private logger: Logger
  ) {
    super(wrapped);
  }

  async read(): Promise<string> {
    this.logger.debug('Reading data...');
    const start = Date.now();
    const data = await super.read();
    this.logger.debug(`Read completed in ${Date.now() - start}ms`);
    return data;
  }

  async write(data: string): Promise<void> {
    this.logger.debug(`Writing ${data.length} bytes...`);
    const start = Date.now();
    await super.write(data);
    this.logger.debug(`Write completed in ${Date.now() - start}ms`);
  }
}

class CachingDecorator extends DataSourceDecorator {
  private cache: string | null = null;
  private lastRead: number = 0;

  constructor(
    wrapped: DataSource,
    private ttlMs: number = 60000
  ) {
    super(wrapped);
  }

  async read(): Promise<string> {
    const now = Date.now();
    if (this.cache && (now - this.lastRead) < this.ttlMs) {
      return this.cache;
    }

    this.cache = await super.read();
    this.lastRead = now;
    return this.cache;
  }

  async write(data: string): Promise<void> {
    this.cache = null; // Invalidate cache
    await super.write(data);
  }
}

// Usage - stack decorators in any order
let dataSource: DataSource = new FileDataSource('./data.json');

// Add compression
dataSource = new CompressionDecorator(dataSource);

// Add encryption on top of compression
dataSource = new EncryptionDecorator(dataSource, 'secret-key');

// Add caching
dataSource = new CachingDecorator(dataSource, 30000);

// Add logging
dataSource = new LoggingDecorator(dataSource, logger);

// Client code doesn't know about decorators
await dataSource.write(JSON.stringify({ user: 'data' }));
const data = await dataSource.read();
```

**Anti-Pattern**: Creating subclasses for every combination of features.

### Pattern 3: Facade

**When to Use**: Providing a simplified interface to a complex subsystem

**Example**:
```typescript
// Complex subsystem classes
class VideoDecoder {
  decode(videoFile: Buffer): DecodedVideo {
    // Complex decoding logic
    return { frames: [], format: 'raw' };
  }
}

class AudioExtractor {
  extract(videoFile: Buffer): AudioTrack {
    // Extract audio track
    return { samples: [], sampleRate: 44100 };
  }
}

class VideoEncoder {
  encode(frames: Frame[], codec: string): Buffer {
    // Complex encoding logic
    return Buffer.from([]);
  }
}

class AudioEncoder {
  encode(audio: AudioTrack, codec: string): Buffer {
    return Buffer.from([]);
  }
}

class Muxer {
  mux(video: Buffer, audio: Buffer, format: string): Buffer {
    // Combine video and audio streams
    return Buffer.from([]);
  }
}

class ThumbnailGenerator {
  generate(frames: Frame[], timestamp: number): Buffer {
    return Buffer.from([]);
  }
}

class SubtitleProcessor {
  burn(frames: Frame[], subtitles: Subtitle[]): Frame[] {
    return frames;
  }
}

// Facade - simplified interface
interface ConversionOptions {
  outputFormat: 'mp4' | 'webm' | 'avi';
  videoCodec?: string;
  audioCodec?: string;
  resolution?: { width: number; height: number };
  thumbnailAt?: number;
  subtitles?: Subtitle[];
}

interface ConversionResult {
  video: Buffer;
  thumbnail?: Buffer;
  duration: number;
}

class VideoConverterFacade {
  private decoder = new VideoDecoder();
  private audioExtractor = new AudioExtractor();
  private videoEncoder = new VideoEncoder();
  private audioEncoder = new AudioEncoder();
  private muxer = new Muxer();
  private thumbnailGen = new ThumbnailGenerator();
  private subtitleProc = new SubtitleProcessor();

  async convert(
    inputFile: Buffer,
    options: ConversionOptions
  ): Promise<ConversionResult> {
    // Step 1: Decode input
    const decoded = this.decoder.decode(inputFile);
    const audio = this.audioExtractor.extract(inputFile);

    // Step 2: Process frames
    let frames = decoded.frames;

    if (options.resolution) {
      frames = this.resizeFrames(frames, options.resolution);
    }

    if (options.subtitles) {
      frames = this.subtitleProc.burn(frames, options.subtitles);
    }

    // Step 3: Encode
    const videoCodec = options.videoCodec || this.getDefaultVideoCodec(options.outputFormat);
    const audioCodec = options.audioCodec || this.getDefaultAudioCodec(options.outputFormat);

    const encodedVideo = this.videoEncoder.encode(frames, videoCodec);
    const encodedAudio = this.audioEncoder.encode(audio, audioCodec);

    // Step 4: Mux
    const output = this.muxer.mux(encodedVideo, encodedAudio, options.outputFormat);

    // Step 5: Optional thumbnail
    let thumbnail: Buffer | undefined;
    if (options.thumbnailAt !== undefined) {
      thumbnail = this.thumbnailGen.generate(frames, options.thumbnailAt);
    }

    return {
      video: output,
      thumbnail,
      duration: this.calculateDuration(frames)
    };
  }

  // Convenience methods
  async convertToMp4(inputFile: Buffer): Promise<Buffer> {
    const result = await this.convert(inputFile, { outputFormat: 'mp4' });
    return result.video;
  }

  async extractThumbnail(inputFile: Buffer, timestamp: number): Promise<Buffer> {
    const decoded = this.decoder.decode(inputFile);
    return this.thumbnailGen.generate(decoded.frames, timestamp);
  }

  private getDefaultVideoCodec(format: string): string {
    return format === 'webm' ? 'vp9' : 'h264';
  }

  private getDefaultAudioCodec(format: string): string {
    return format === 'webm' ? 'opus' : 'aac';
  }

  private resizeFrames(frames: Frame[], resolution: { width: number; height: number }): Frame[] {
    return frames; // Resize logic
  }

  private calculateDuration(frames: Frame[]): number {
    return frames.length / 30; // Assuming 30fps
  }
}

// Usage - client only needs to know the facade
const converter = new VideoConverterFacade();

// Simple conversion
const mp4 = await converter.convertToMp4(inputBuffer);

// Advanced conversion with options
const result = await converter.convert(inputBuffer, {
  outputFormat: 'webm',
  resolution: { width: 1920, height: 1080 },
  thumbnailAt: 5,
  subtitles: loadSubtitles('./subs.srt')
});
```

**Anti-Pattern**: Facade that exposes all subsystem classes instead of simplifying.

### Pattern 4: Proxy

**When to Use**: Controlling access, lazy loading, or logging

**Example**:
```typescript
// Subject interface
interface Image {
  display(): void;
  getInfo(): ImageInfo;
}

// Real subject (expensive to create)
class HighResolutionImage implements Image {
  private pixels: Buffer;

  constructor(private path: string) {
    // Expensive operation - loads entire image into memory
    console.log(`Loading image from ${path}...`);
    this.pixels = fs.readFileSync(path);
  }

  display(): void {
    console.log(`Displaying ${this.path} (${this.pixels.length} bytes)`);
  }

  getInfo(): ImageInfo {
    return {
      path: this.path,
      size: this.pixels.length,
      loaded: true
    };
  }
}

// Virtual Proxy - lazy loading
class ImageProxy implements Image {
  private realImage: HighResolutionImage | null = null;

  constructor(private path: string) {}

  display(): void {
    if (!this.realImage) {
      this.realImage = new HighResolutionImage(this.path);
    }
    this.realImage.display();
  }

  getInfo(): ImageInfo {
    if (this.realImage) {
      return this.realImage.getInfo();
    }
    // Return info without loading
    return {
      path: this.path,
      size: fs.statSync(this.path).size,
      loaded: false
    };
  }
}

// Protection Proxy - access control
class ProtectedImage implements Image {
  constructor(
    private realImage: Image,
    private accessLevel: string,
    private requiredLevel: string
  ) {}

  display(): void {
    if (!this.hasAccess()) {
      throw new Error('Access denied');
    }
    this.realImage.display();
  }

  getInfo(): ImageInfo {
    return this.realImage.getInfo();
  }

  private hasAccess(): boolean {
    const levels = ['public', 'internal', 'confidential', 'secret'];
    return levels.indexOf(this.accessLevel) >= levels.indexOf(this.requiredLevel);
  }
}

// Caching Proxy
class CachedApiClient implements ApiClient {
  private cache: Map<string, { data: any; expiry: number }> = new Map();

  constructor(
    private realClient: ApiClient,
    private ttlMs: number = 60000
  ) {}

  async get(url: string): Promise<any> {
    const cached = this.cache.get(url);
    if (cached && cached.expiry > Date.now()) {
      console.log(`Cache hit for ${url}`);
      return cached.data;
    }

    console.log(`Cache miss for ${url}`);
    const data = await this.realClient.get(url);
    this.cache.set(url, {
      data,
      expiry: Date.now() + this.ttlMs
    });
    return data;
  }
}

// Logging Proxy
class LoggingApiClient implements ApiClient {
  constructor(
    private realClient: ApiClient,
    private logger: Logger
  ) {}

  async get(url: string): Promise<any> {
    const start = Date.now();
    this.logger.info(`API GET ${url}`);

    try {
      const result = await this.realClient.get(url);
      this.logger.info(`API GET ${url} completed in ${Date.now() - start}ms`);
      return result;
    } catch (error) {
      this.logger.error(`API GET ${url} failed: ${error.message}`);
      throw error;
    }
  }
}

// Usage
const gallery: Image[] = [
  new ImageProxy('/images/photo1.jpg'),
  new ImageProxy('/images/photo2.jpg'),
  new ImageProxy('/images/photo3.jpg')
];

// Images not loaded yet
gallery.forEach(img => console.log(img.getInfo()));

// Only loads when displayed
gallery[0].display(); // Loads and displays
gallery[0].display(); // Already loaded, just displays

// Stacked proxies
let apiClient: ApiClient = new RealApiClient();
apiClient = new CachedApiClient(apiClient, 30000);
apiClient = new LoggingApiClient(apiClient, logger);
```

**Anti-Pattern**: Proxy that breaks the contract of the real subject.

### Pattern 5: Composite

**When to Use**: Treating individual objects and compositions uniformly

**Example**:
```typescript
// Component
interface FileSystemNode {
  getName(): string;
  getSize(): number;
  print(indent?: string): void;
  find(predicate: (node: FileSystemNode) => boolean): FileSystemNode[];
}

// Leaf
class File implements FileSystemNode {
  constructor(
    private name: string,
    private size: number
  ) {}

  getName(): string {
    return this.name;
  }

  getSize(): number {
    return this.size;
  }

  print(indent: string = ''): void {
    console.log(`${indent}📄 ${this.name} (${this.size} bytes)`);
  }

  find(predicate: (node: FileSystemNode) => boolean): FileSystemNode[] {
    return predicate(this) ? [this] : [];
  }
}

// Composite
class Directory implements FileSystemNode {
  private children: FileSystemNode[] = [];

  constructor(private name: string) {}

  getName(): string {
    return this.name;
  }

  getSize(): number {
    return this.children.reduce((sum, child) => sum + child.getSize(), 0);
  }

  print(indent: string = ''): void {
    console.log(`${indent}📁 ${this.name}/`);
    this.children.forEach(child => child.print(indent + '  '));
  }

  find(predicate: (node: FileSystemNode) => boolean): FileSystemNode[] {
    const results: FileSystemNode[] = [];

    if (predicate(this)) {
      results.push(this);
    }

    this.children.forEach(child => {
      results.push(...child.find(predicate));
    });

    return results;
  }

  add(node: FileSystemNode): void {
    this.children.push(node);
  }

  remove(node: FileSystemNode): void {
    const index = this.children.indexOf(node);
    if (index > -1) {
      this.children.splice(index, 1);
    }
  }

  getChildren(): FileSystemNode[] {
    return [...this.children];
  }
}

// Usage
const root = new Directory('project');

const src = new Directory('src');
src.add(new File('index.ts', 1024));
src.add(new File('app.ts', 2048));

const components = new Directory('components');
components.add(new File('Button.tsx', 512));
components.add(new File('Input.tsx', 768));
src.add(components);

root.add(src);
root.add(new File('package.json', 256));
root.add(new File('README.md', 512));

// Treat uniformly
root.print();
console.log(`Total size: ${root.getSize()} bytes`);

// Find all .tsx files
const tsxFiles = root.find(node =>
  node.getName().endsWith('.tsx')
);
```

**Anti-Pattern**: Type checking to distinguish between leaves and composites in client code.

### Pattern 6: Bridge

**When to Use**: Separating abstraction from implementation

**Example**:
```typescript
// Implementation interface
interface MessageSender {
  send(message: string, recipient: string): Promise<void>;
}

// Concrete implementations
class EmailSender implements MessageSender {
  constructor(private smtpConfig: SmtpConfig) {}

  async send(message: string, recipient: string): Promise<void> {
    console.log(`Sending email to ${recipient}: ${message}`);
    // SMTP implementation
  }
}

class SMSSender implements MessageSender {
  constructor(private twilioConfig: TwilioConfig) {}

  async send(message: string, recipient: string): Promise<void> {
    console.log(`Sending SMS to ${recipient}: ${message}`);
    // Twilio implementation
  }
}

class PushNotificationSender implements MessageSender {
  constructor(private firebaseConfig: FirebaseConfig) {}

  async send(message: string, recipient: string): Promise<void> {
    console.log(`Sending push to ${recipient}: ${message}`);
    // Firebase implementation
  }
}

// Abstraction
abstract class Notification {
  constructor(protected sender: MessageSender) {}

  abstract notify(user: User): Promise<void>;
}

// Refined abstractions
class UrgentNotification extends Notification {
  async notify(user: User): Promise<void> {
    const message = `🚨 URGENT: ${this.getMessage()}`;
    await this.sender.send(message, this.getRecipient(user));
  }

  protected abstract getMessage(): string;
  protected abstract getRecipient(user: User): string;
}

class RegularNotification extends Notification {
  async notify(user: User): Promise<void> {
    const message = this.getMessage();
    await this.sender.send(message, this.getRecipient(user));
  }

  protected abstract getMessage(): string;
  protected abstract getRecipient(user: User): string;
}

// Concrete notifications
class OrderConfirmation extends RegularNotification {
  constructor(
    sender: MessageSender,
    private order: Order
  ) {
    super(sender);
  }

  protected getMessage(): string {
    return `Your order #${this.order.id} has been confirmed!`;
  }

  protected getRecipient(user: User): string {
    return user.email;
  }
}

class SecurityAlert extends UrgentNotification {
  constructor(
    sender: MessageSender,
    private alertType: string
  ) {
    super(sender);
  }

  protected getMessage(): string {
    return `Security alert: ${this.alertType}`;
  }

  protected getRecipient(user: User): string {
    return user.phone;
  }
}

// Usage - mix abstractions with implementations
const emailSender = new EmailSender(smtpConfig);
const smsSender = new SMSSender(twilioConfig);
const pushSender = new PushNotificationSender(firebaseConfig);

// Same notification type, different delivery methods
const orderEmailNotif = new OrderConfirmation(emailSender, order);
const orderPushNotif = new OrderConfirmation(pushSender, order);

// Same delivery method, different notification types
const securitySmsAlert = new SecurityAlert(smsSender, 'New login detected');
const securityPushAlert = new SecurityAlert(pushSender, 'Password changed');

await orderEmailNotif.notify(user);
await securitySmsAlert.notify(user);
```

**Anti-Pattern**: Explosion of subclasses for every combination of abstraction and implementation.

## Checklist

- [ ] Adapter used for incompatible interfaces
- [ ] Decorator used instead of subclass explosion
- [ ] Facade simplifies complex subsystems
- [ ] Proxy controls access appropriately
- [ ] Composite treats parts and wholes uniformly
- [ ] Bridge separates varying dimensions
- [ ] Patterns combined when appropriate
- [ ] Client code depends on abstractions

## References

- [Design Patterns: Elements of Reusable Object-Oriented Software](https://www.amazon.com/Design-Patterns-Elements-Reusable-Object-Oriented/dp/0201633612)
- [Refactoring Guru - Structural Patterns](https://refactoring.guru/design-patterns/structural-patterns)
- [Head First Design Patterns](https://www.amazon.com/Head-First-Design-Patterns-Brain-Friendly/dp/0596007124)
