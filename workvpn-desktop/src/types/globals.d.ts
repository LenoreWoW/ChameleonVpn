// Type declarations for global libraries loaded via CDN

// Environment info exposed from preload
interface EnvInfo {
  NODE_ENV: string;
  isDevelopment: boolean;
  isProduction: boolean;
}

interface Window {
  env: EnvInfo;
}

declare namespace gsap {
  interface GSAPStatic {
    fromTo(target: any, vars: object, vars2: object): any;
    from(target: any, vars: object): any;
    to(target: any, vars: object): any;
  }
}

// THREE.js basic types
declare namespace THREE {
  class Scene {}
  class PerspectiveCamera {
    constructor(fov: number, aspect: number, near: number, far: number);
    position: { x: number; y: number; z: number };
    aspect: number;
    updateProjectionMatrix(): void;
    lookAt(position: { x: number; y: number; z: number }): void;
  }
  class WebGLRenderer {
    constructor(options?: any);
    domElement: HTMLCanvasElement;
    setSize(width: number, height: number): void;
    setPixelRatio(ratio: number): void;
    render(scene: Scene, camera: PerspectiveCamera): void;
    dispose(): void;
  }
  class Fog {
    constructor(color: number, near: number, far: number);
  }
  class BufferGeometry {
    setAttribute(name: string, attribute: BufferAttribute): void;
    dispose(): void;
  }
  class BufferAttribute {
    constructor(array: Float32Array, itemSize: number);
  }
  class Float32BufferAttribute extends BufferAttribute {}
  class PointsMaterial {
    constructor(options?: any);
    dispose(): void;
  }
  class LineBasicMaterial {
    constructor(options?: any);
    color: Color;
    dispose(): void;
  }
  class Points {
    constructor(geometry: BufferGeometry, material: PointsMaterial);
    geometry: BufferGeometry;
    material: PointsMaterial;
    rotation: { x: number; y: number; z: number };
  }
  class LineSegments {
    constructor(geometry: BufferGeometry, material: LineBasicMaterial);
    geometry: BufferGeometry;
    material: LineBasicMaterial;
    rotation: { x: number; y: number; z: number };
  }
  class Color {
    constructor(color: number);
    r: number;
    g: number;
    b: number;
    setHex(hex: number): this;
  }
  class Vector2 {
    x: number;
    y: number;
  }
  const AdditiveBlending: number;
}

// ThreeScene class
declare class ThreeScene {
  constructor(container: HTMLElement);
  setColor(color: number): void;
  destroy(): void;
}
