out vec3 lightDir1, lightDir2, normal, eyeVec;
out vec2 texCoord0;

in vec3 uv_vertexAttrib;
in vec3 uv_normalAttrib;
in vec2 uv_texCoordAttrib0;

uniform vec4 uv_lightPos;

uniform mat4 uv_modelViewProjectionMatrix;

uniform mat4 uv_object2SceneMatrix;
uniform mat4 uv_scene2ObjectMatrix;
uniform vec4 uv_cameraPos;

uniform float uv_time;
uniform int uv_simulationtimeDays;
uniform float uv_simulationtimeSeconds;

const float PI = 3.141592653589793;

//from https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
//simple 3D noise
float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}
float snoise(vec3 p){
	vec3 a = floor(p);
	vec3 d = p - a;
	d = d * d * (3.0 - 2.0 * d);

	vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 k1 = perm(b.xyxy);
	vec4 k2 = perm(k1.xyxy + b.zzww);

	vec4 c = k2 + a.zzzz;
	vec4 k3 = perm(c);
	vec4 k4 = perm(c + 1.0);

	vec4 o1 = fract(k3 * (1.0 / 41.0));
	vec4 o2 = fract(k4 * (1.0 / 41.0));

	vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
	vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

	return o4.y * d.y + o4.x * (1.0 - d.y);
}

// from https://www.seedofandromeda.com/blogs/49-procedural-gas-giant-rendering-with-gpu-noise
//fractal noise
float noise(vec3 position, int octaves, float frequency, float persistence, int rigid) {
	float total = 0.0; // Total value so far
	float maxAmplitude = 0.0; // Accumulates highest theoretical amplitude
	float amplitude = 1.0;
	const int largeN = 50;
	for (int i = 0; i < largeN; i++) {
		if (i > octaves){
				break;
		}
		// Get the noise sample
		if (rigid == 0){
		   total += snoise(position * frequency) * amplitude;
		} else {
		// rigid noise
			total += ((1.0 - abs(snoise(position * frequency))) * 2.0 - 1.0) * amplitude;
		}
		// Make the wavelength twice as small
		frequency *= 2.0;
		// Add to our maximum possible amplitude
		maxAmplitude += amplitude;
		// Reduce amplitude according to persistence for the next octave
		amplitude *= persistence;
	}

	// Scale the result by the maximum amplitude
	return total / maxAmplitude;
}


mat3 rotationMatrix(vec3 axis, float angle)
{
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	
	return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
				oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
				oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
}


void main(void)
{

	//define the time 
	float dayfract = uv_simulationtimeSeconds/(24.0*3600.0);
	float days = uv_simulationtimeDays + dayfract;
	float angle = mod(days/30., 2.*PI);

	mat4 normalMatrix = transpose( uv_scene2ObjectMatrix );
	
	normal = (normalMatrix * vec4(uv_normalAttrib,0.0)).xyz;
	
	//apply a solid body rotation matched with the edge of the accretion disk
	vec3 rVertex = rotationMatrix(vec3(0,1,0), angle)*uv_vertexAttrib;
	
	//add some noisy motion along the normal direction
	vec3 pNorm = vec3(uv_normalAttrib.xy/10., angle);

	//fractal noise
	float n1 = noise(pNorm, 7, 3., 0.7, 1); 
	float s = 0.1;
	float frequency = 3;//
	float threshold = 0.5;// limit number of spots
	float t1 = snoise(pNorm * frequency) - s;
	float t2 = snoise((pNorm + 30.) * frequency) - s;
	float ss = (max(t1 * t2, threshold) - threshold) ;
	// Accumulate total noise
	float n =clamp(n1 - ss + 0.3, 0, 1);
	
	//rVertex += normal.xyz*n*700.;
	
	//vec4 vertex = uv_modelViewProjectionMatrix* vec4(uv_vertexAttrib ,1.0);	
	gl_Position = vec4(rVertex ,1.0);

	vec3 vVertex = vec3(uv_object2SceneMatrix* vec4(uv_vertexAttrib,1.0));
	vec3 tmpVec = normalize( (uv_object2SceneMatrix* uv_lightPos).xyz );

	//point light at center
	lightDir1 = -1.*vVertex.xyz;

	//some diffuse lighting from the opposite direction
	lightDir2 = vVertex.xyz;

	eyeVec = uv_cameraPos.xyz-vVertex;

	texCoord0.s  = uv_texCoordAttrib0.s;
	texCoord0.t  = uv_texCoordAttrib0.t;
}