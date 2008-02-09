#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include <GL/glew.h>
#include <GL/glut.h>

#include "funslang.h"

#define WINDOW_W 1000
#define WINDOW_H 1000

GLfloat g_ModelMatrixFaceA[4][4] =
{
	{ 1,  0,  0,  0},
	{ 0,  1,  0,  0},
	{ 0,  0,  1,  0},
	{ 0,  0,  0,  1},
};
GLfloat g_ModelMatrixFaceB[4][4] =
{
	{ 0,  0, -1,  0},
	{ 0,  1,  0,  0},
	{ 1,  0,  0,  0},
	{ 0,  0,  0,  1},
};
GLfloat g_ModelMatrixFaceC[4][4] =
{
	{-1,  0,  0,  0},
	{ 0,  1,  0,  0},
	{ 0,  0, -1,  0},
	{ 0,  0,  0,  1},
};
GLfloat g_ModelMatrixFaceD[4][4] =
{
	{ 0,  0,  1,  0},
	{ 0,  1,  0,  0},
	{-1,  0,  0,  0},
	{ 0,  0,  0,  1},
};

GLfloat g_ModelMatrixFaceE[4][4] =
{
	{ 1,  0,  0,  0},
	{ 0,  0,  1,  0},
	{ 0, -1,  0,  0},
	{ 0,  0,  0,  1},
};
GLfloat g_ModelMatrixFaceF[4][4] =
{
	{ 1,  0,  0,  0},
	{ 0,  0, -1,  0},
	{ 0,  1,  0,  0},
	{ 0,  0,  0,  1},
};

const GLfloat g_vv[4*3] =
{
	-1, -1, +1,
	+1, -1, +1,
	+1, +1, +1,
	-1, +1, +1,
};


typedef struct
{
	float proj[4][4];
	float model[4][4];
	float rotx;
	float roty;
	float rotz;
	float from[3];
	float to[3];
	float up[3];
} VertexUniforms;

VertexUniforms g_vu =
{
	{
		{0, 0, 0, 0},
		{0, 0, 0, 0},
		{0, 0, 0, 0},
		{0, 0, 0, 0},
	},
	{
		{0, 0, 0, 0},
		{0, 0, 0, 0},
		{0, 0, 0, 0},
		{0, 0, 0, 0},
	},
	0,
	0,
	0,
	{1.5,1.5,1.5},
	{0,0,0},
	{0,1,0},
};

typedef struct
{
	float Zoom;
	float Xcenter;
	float Ycenter;
	float InnerColor[3];
	float OuterColor1[3];
	float OuterColor2[3];
} FragmentUniforms;

FragmentUniforms g_fu =
{
	2,
	0,
	0,
	{0, 0, 0},
	{1, 0.5, 0},
	{1, 0, 0},
};


int g_FrameNumThisTick = 0, g_TickTime = 0, g_Time, g_TimeDelta;
double g_PhaseDelta;

bool g_IsRotatingX = false;
bool g_IsRotatingY = false;
bool g_IsRotatingZ = false;
bool g_IsZooming = false;

FSprogram g_Program;


void updateFPS(void)
{
	g_FrameNumThisTick++;
	
	int t = glutGet(GLUT_ELAPSED_TIME);
	g_TimeDelta = g_Time - t;
	g_PhaseDelta = 2 * M_PI * g_TimeDelta / 1000.0;
	g_Time = t;
	
	int timeThisTick = g_Time - g_TickTime;
	
	if (timeThisTick > 1000)
	{
		printf("FPS:%4.2f\n", (g_FrameNumThisTick * 1000.0) / timeThisTick);
		
		g_TickTime = g_Time;
		g_FrameNumThisTick = 0;
	}
}

void key(unsigned char key, int x, int y)
{
	switch (key)
	{
		case 'i':
			g_IsRotatingX = !g_IsRotatingX;
			return;
		case 'j':
			g_IsRotatingY = !g_IsRotatingY;
			return;
		case 'k':
			g_IsRotatingZ = !g_IsRotatingZ;
			return;
		case 'z':
			g_IsZooming = !g_IsZooming;
			return;
	}
}

void render(void)
{
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	memcpy(g_vu.model, g_ModelMatrixFaceA, 16 * sizeof(GLfloat));
	fsSetVertexUniforms(&g_Program, (GLfloat*)&g_vu);
	fsSetFragmentUniforms(&g_Program, (GLfloat*)&g_fu);
	glDrawArrays(GL_QUADS, 0, 4);
	
	memcpy(g_vu.model, g_ModelMatrixFaceB, 16 * sizeof(GLfloat));
	fsSetVertexUniforms(&g_Program, (GLfloat*)&g_vu);
	fsSetFragmentUniforms(&g_Program, (GLfloat*)&g_fu);
	glDrawArrays(GL_QUADS, 0, 4);
	
	memcpy(g_vu.model, g_ModelMatrixFaceC, 16 * sizeof(GLfloat));
	fsSetVertexUniforms(&g_Program, (GLfloat*)&g_vu);
	fsSetFragmentUniforms(&g_Program, (GLfloat*)&g_fu);
	glDrawArrays(GL_QUADS, 0, 4);
	
	memcpy(g_vu.model, g_ModelMatrixFaceD, 16 * sizeof(GLfloat));
	fsSetVertexUniforms(&g_Program, (GLfloat*)&g_vu);
	fsSetFragmentUniforms(&g_Program, (GLfloat*)&g_fu);
	glDrawArrays(GL_QUADS, 0, 4);
	
	memcpy(g_vu.model, g_ModelMatrixFaceE, 16 * sizeof(GLfloat));
	fsSetVertexUniforms(&g_Program, (GLfloat*)&g_vu);
	fsSetFragmentUniforms(&g_Program, (GLfloat*)&g_fu);
	glDrawArrays(GL_QUADS, 0, 4);
	
	memcpy(g_vu.model, g_ModelMatrixFaceF, 16 * sizeof(GLfloat));
	fsSetVertexUniforms(&g_Program, (GLfloat*)&g_vu);
	fsSetFragmentUniforms(&g_Program, (GLfloat*)&g_fu);
	glDrawArrays(GL_QUADS, 0, 4);
	
	glutSwapBuffers();
}

void frame(void)
{
	updateFPS();
	
	if (g_IsRotatingX)
	{
		static double phase = 0;
		phase += g_PhaseDelta / 4;
		g_vu.rotx = phase;
	}
	if (g_IsRotatingY)
	{
		static double phase = 0;
		phase += g_PhaseDelta / 4;
		g_vu.roty = phase;
	}
	if (g_IsRotatingZ)
	{
		static double phase = 0;
		phase += g_PhaseDelta / 4;
		g_vu.rotz = phase;
	}
	if (g_IsZooming)
	{
		static double phase = 0;
		phase += 2 * M_PI * g_TimeDelta / 1000.0;
		g_fu.Zoom = 1.1 + 0.9 * cos(phase);
	}
	
	render();
}


int main(int argc, char** argv)
{
	// Init funslang compiler and the Haskell runtime.
	fsInit(&argc, &argv);
	
	// Create window.
	glutInit(&argc,argv);
	glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
	glutInitWindowSize(WINDOW_W, WINDOW_H);
	glutCreateWindow("demo");

	// Check for the required extensions.
	if (GLEW_OK != glewInit() || !GLEW_VERSION_2_0)
	{
		printf("OpenGL 2.0 is required!");
		return 1;
	}
	
	// Enable back-face culling.
	glEnable(GL_CULL_FACE);

	// Steal projection matrix from GL.
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(60.0, 1.0, 1.0, 10.0);
	glGetFloatv(GL_PROJECTION_MATRIX, (GLfloat*)&g_vu.proj);
	
	// Init shaders.
	g_Program.vertex_shader_path = "../funslang/Mandelbrot.vp";
	g_Program.fragment_shader_path = "../funslang/Mandelbrot.fp";
	if (!fsCompile(&g_Program)) return 1;
	glUseProgram(g_Program.glsl_program);
	fsSetVertexVaryings(&g_Program, (GLfloat*)&g_vv);
	
	// Set up GLUT callbacks.
	glutDisplayFunc(render);
	glutIdleFunc(frame);
	glutKeyboardFunc(key);

	// Enter main loop.
	glutMainLoop();

	return 0;
}
