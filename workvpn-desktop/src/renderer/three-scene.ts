import * as THREE from 'three';

/**
 * Three.js Animated Background Scene
 * Creates a stunning 3D particle network with blue theme
 */
export class ThreeScene {
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private renderer: THREE.WebGLRenderer;
  private particles: THREE.Points;
  private lines: THREE.LineSegments;
  private mouse: THREE.Vector2;
  private animationId: number | null = null;

  constructor(container: HTMLElement) {
    // Scene setup
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.Fog(0x0a0e27, 1, 1000);

    // Camera setup
    this.camera = new THREE.PerspectiveCamera(
      75,
      container.clientWidth / container.clientHeight,
      1,
      1000
    );
    this.camera.position.z = 400;

    // Renderer setup
    this.renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true
    });
    this.renderer.setSize(container.clientWidth, container.clientHeight);
    this.renderer.setPixelRatio(window.devicePixelRatio);
    container.appendChild(this.renderer.domElement);

    // Mouse tracking
    this.mouse = new THREE.Vector2();

    // Create particles and network
    this.particles = this.createParticles();
    this.lines = this.createLines();

    // Event listeners
    this.setupEventListeners(container);

    // Start animation
    this.animate();
  }

  private createParticles(): THREE.Points {
    const particlesGeometry = new THREE.BufferGeometry();
    const particlesCount = 1500;
    const positions = new Float32Array(particlesCount * 3);
    const colors = new Float32Array(particlesCount * 3);
    const sizes = new Float32Array(particlesCount);

    // Blue color palette
    const color1 = new THREE.Color(0x00d4ff); // Cyan blue
    const color2 = new THREE.Color(0x0066ff); // Deep blue
    const color3 = new THREE.Color(0x3399ff); // Medium blue

    for (let i = 0; i < particlesCount; i++) {
      const i3 = i * 3;

      // Random positions in 3D space
      positions[i3] = (Math.random() - 0.5) * 800;
      positions[i3 + 1] = (Math.random() - 0.5) * 800;
      positions[i3 + 2] = (Math.random() - 0.5) * 800;

      // Random color from palette
      const colorChoice = Math.random();
      const color = colorChoice < 0.33 ? color1 : colorChoice < 0.66 ? color2 : color3;
      colors[i3] = color.r;
      colors[i3 + 1] = color.g;
      colors[i3 + 2] = color.b;

      // Random sizes
      sizes[i] = Math.random() * 2 + 1;
    }

    particlesGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    particlesGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    particlesGeometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1));

    const particlesMaterial = new THREE.PointsMaterial({
      size: 3,
      vertexColors: true,
      blending: THREE.AdditiveBlending,
      transparent: true,
      opacity: 0.8,
      sizeAttenuation: true,
    });

    const particles = new THREE.Points(particlesGeometry, particlesMaterial);
    this.scene.add(particles);

    return particles;
  }

  private createLines(): THREE.LineSegments {
    const linesGeometry = new THREE.BufferGeometry();
    const linesMaterial = new THREE.LineBasicMaterial({
      color: 0x0088ff,
      transparent: true,
      opacity: 0.2,
      blending: THREE.AdditiveBlending,
    });

    const lines = new THREE.LineSegments(linesGeometry, linesMaterial);
    this.scene.add(lines);

    return lines;
  }

  private updateConnections() {
    const positions = this.particles.geometry.attributes.position.array as Float32Array;
    const particlesCount = positions.length / 3;
    const maxDistance = 120;
    const linePositions: number[] = [];

    // Connect nearby particles
    for (let i = 0; i < particlesCount; i++) {
      const i3 = i * 3;
      const x1 = positions[i3];
      const y1 = positions[i3 + 1];
      const z1 = positions[i3 + 2];

      // Check only a subset of particles for performance
      const checkCount = Math.min(50, particlesCount - i - 1);
      for (let j = i + 1; j < i + checkCount && j < particlesCount; j++) {
        const j3 = j * 3;
        const x2 = positions[j3];
        const y2 = positions[j3 + 1];
        const z2 = positions[j3 + 2];

        const dx = x1 - x2;
        const dy = y1 - y2;
        const dz = z1 - z2;
        const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);

        if (distance < maxDistance) {
          linePositions.push(x1, y1, z1);
          linePositions.push(x2, y2, z2);
        }
      }
    }

    this.lines.geometry.setAttribute(
      'position',
      new THREE.Float32BufferAttribute(linePositions, 3)
    );
  }

  private setupEventListeners(container: HTMLElement) {
    window.addEventListener('resize', () => {
      this.camera.aspect = container.clientWidth / container.clientHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(container.clientWidth, container.clientHeight);
    });

    container.addEventListener('mousemove', (event) => {
      this.mouse.x = (event.clientX / container.clientWidth) * 2 - 1;
      this.mouse.y = -(event.clientY / container.clientHeight) * 2 + 1;
    });
  }

  private animate = () => {
    this.animationId = requestAnimationFrame(this.animate);

    // Rotate particle system
    this.particles.rotation.x += 0.0005;
    this.particles.rotation.y += 0.001;

    // Rotate lines
    this.lines.rotation.x += 0.0005;
    this.lines.rotation.y += 0.001;

    // Camera follows mouse slightly
    this.camera.position.x += (this.mouse.x * 50 - this.camera.position.x) * 0.05;
    this.camera.position.y += (this.mouse.y * 50 - this.camera.position.y) * 0.05;
    this.camera.lookAt(this.scene.position);

    // Update particle connections periodically (every 10 frames for performance)
    if (Math.random() > 0.9) {
      this.updateConnections();
    }

    this.renderer.render(this.scene, this.camera);
  };

  public setColor(color: number) {
    const material = this.lines.material as THREE.LineBasicMaterial;
    material.color.setHex(color);
  }

  public destroy() {
    if (this.animationId !== null) {
      cancelAnimationFrame(this.animationId);
    }
    this.renderer.dispose();
    this.particles.geometry.dispose();
    (this.particles.material as THREE.Material).dispose();
    this.lines.geometry.dispose();
    (this.lines.material as THREE.Material).dispose();
  }
}
