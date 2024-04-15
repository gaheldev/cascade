#include <math.h>
#include <stdio.h>
#include <string>

#include "fmod.hpp"



extern "C"
{
	F_EXPORT FMOD_DSP_DESCRIPTION* F_CALL FMODGetDSPDescription();
}

FMOD_RESULT F_CALLBACK Plugin_Create  (FMOD_DSP_STATE *dsp_state);

FMOD_RESULT F_CALLBACK Plugin_Release (FMOD_DSP_STATE *dsp_state);

FMOD_RESULT F_CALLBACK Plugin_Process (FMOD_DSP_STATE *dsp_state,
				       unsigned int length,
				       const FMOD_DSP_BUFFER_ARRAY *inbufferarray,
				       FMOD_DSP_BUFFER_ARRAY *outbufferarray,
				       FMOD_BOOL inputsidle,
				       FMOD_DSP_PROCESS_OPERATION op);

FMOD_RESULT F_CALLBACK Plugin_SetBool (FMOD_DSP_STATE *dsp_state,
				       int index,
				       FMOD_BOOL value);

FMOD_RESULT F_CALLBACK Plugin_GetBool (FMOD_DSP_STATE *dsp_state,
				       int index,
				       FMOD_BOOL *value, 
				       char *valuestr);



//------------- Parameters ----------------

static FMOD_DSP_PARAMETER_DESC mute;

FMOD_DSP_PARAMETER_DESC* Silence_DSP_Param[1] =
{
	&mute
};


//------------- Plugin description ----------------

FMOD_DSP_DESCRIPTION Silence_Desc =
{
	FMOD_PLUGIN_SDK_VERSION,    // version
	"Chord",            	    // name
	0x00010000,                 // plugin version
	0,                          // no. input buffers
	1,                          // no. output buffers
	Plugin_Create,              // create
	Plugin_Release,             // release
	0,                          // reset
	0,                          // read
	Plugin_Process,             // process
	0,                          // setposition
	1,                          // no. parameter
	Silence_DSP_Param,          // pointer to parameter descriptions
	0,                          // Set float
	0,                          // Set int
	Plugin_SetBool,             // Set bool
	0,                          // Set data
	0,                          // Get float
	0,                          // Get int
	Plugin_GetBool,             // Get bool
	0,                          // Get data
	0,                          // Check states before processing
	0,                          // User data
	0,                          // System register
	0,                          // System deregister
	0                           // Mixer thread execute / after execute
};



extern "C"
{

F_EXPORT FMOD_DSP_DESCRIPTION* F_CALL FMODGetDSPDescription ()
{
	FMOD_DSP_INIT_PARAMDESC_BOOL(mute, "Mute", "", "Whether this plugin lets through audio or not", false, 0);
	return &Silence_Desc;
}

}
