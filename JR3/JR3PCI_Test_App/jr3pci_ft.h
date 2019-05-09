// JR3PCI_FT.h Version 3.00  * Header file *
// JR3 force/torque sensor module for Win32 Operating Systems
// to use with PCI Receiver Boards

// Author: J. Norberto Pires      Date: 19.04.97  Last Edit: 05.12.01
// Revision:                      Date:

// Robotics and Control Laboratory
// Mechanical Engineering Department
// University of Coimbra - PORTUGAL

// *****************************************************************************

// History
// 19.04.97 - Defined data and added comments
// 20.04.97 - Tested for errors and read copyright from sensor
// 25.05.97 - Tested all functions
// 12.06.01 - Added PCI simple interface
// 13.06.01 - PCI interface tested and functional
// 05.12.01 - PCI interface for several types of boards (multi-processor boards)
// *****************************************************************************

// debbug info:
// Things to check marked with the "Check this norby" label.

// *****************************************************************************

// PCI definitions
#define Jr3ResetAddr 0x18000
#define Jr3NoAddrMask 0x40000
#define Jr3DmAddrMask 0x6000
//int Jr3BaseAddress = 0;
//int Jr3BaseSize = 0;

// Operating System definitions
#define WINDOWS_NT2000		0x0000
#define WINDOWS_9598		0x0001
#define WINDOWS_3X			0x0002
#define UNSUPORTED_OS		0x0003


// Usable offsets at JR3 DSP memory space
#define RAW_C			0x0000
#define COPYRIGHT 		0x0040
#define SHUNTS			0x0060
#define DEFAULT_F 		0x0068
#define LOAD_E_N  		0x006f
#define MIN_F_S			0x0070
#define TRANSFORM_N		0x0077
#define MAX_F_S 		0x0078
#define PEAK_A			0x007f
#define FULL_S			0x0080
#define OFFSETS			0x0088
#define OFFSET_N		0x008e
#define VECT_A			0x008f
#define FILTER0			0x0090
#define FILTER1			0x0098
#define FILTER2			0x00a0
#define FILTER3			0x00a8
#define FILTER4			0x00b0
#define FILTER5			0x00b8
#define FILTER6			0x00c0
#define RATE_DA			0x00c8
#define MINIMUM_D		0x00d0
#define MAXIMUM_D		0x00d8
#define NEAR_S_V		0x00e0
#define SAT_V			0x00e1
#define RATE_A			0x00e2
#define RATE_DI			0x00e3
#define RATE_C			0x00e4
#define COMMAND_W2		0x00e5
#define COMMAND_W1		0x00e6
#define COMMAND_W0		0x00e7
#define COUNT1			0x00e8
#define COUNT2			0x00e9
#define COUNT3			0x00ea
#define COUNT4			0x00eb
#define COUNT5			0x00ec
#define COUNT6			0x00ed
#define ERROR_C			0x00ee
#define COUNT_X			0x00ef
#define WARNINGS		0x00f0
#define ERRORS			0x00f1
#define THRESHOLD_B		0x00f2
#define LAST_C			0x00f3
#define EEPROM_V_N		0x00f4
#define SOFTWARE_V_N	0x00f5
#define SOFTWARE_D		0x00f6
#define SOFTWARE_Y		0x00f7
#define SERIAL_N		0x00f8
#define MODEL_N			0x00f9
#define CAL_D			0x00fa
#define CAL_Y			0x00fb
#define UNITS			0x00fc
#define BITS			0x00fd
#define CHANNELS		0x00fe
#define THICKNESS		0x00ff
#define LOAD_E			0x0100
#define TRANSFORMS		0x0200

// Data structures definition. The following structures are used by the sensor
// data definition (bellow).

// F_M_SATURATION
// Created to hold saturation bits
typedef struct f_m_saturation
{
 unsigned short fx_sat : 1;
 unsigned short fy_sat : 1;
 unsigned short fz_sat : 1;
 unsigned short mx_sat : 1;
 unsigned short my_sat : 1;
 unsigned short mz_sat : 1;
 unsigned short not_used : 10;
} f_m_saturation;

// RAW_CHANNEL
// Each channel uses 4 two-byte words.
// Raw_time contains the DSP internal clock time when the sample was received.
// The clock runs at 1/10 of the cycle time: 10Mhz means a 1MHz clock.
// Raw_data is the raw data received directly from the sensor.
// The sensor data stream can represent 16 channels:
// Channel 0     - Contains the sensor excitation voltage.
// Channel 1-6   - Contains the coupled force data Fx, Fy, Fz, Mx, My and Mz.
// Channel 7     - Contains the sensor calibration data.
// Channel 8-15  - Reserved. Depends on sensor model.
typedef struct raw_channel
{
 unsigned short raw_time;
 short raw_data;
 short reserved[2];
} raw_channel;

// FORCE_ARRAY
// Layout for the decoupled (after extracting offsets) and filtered force data.
typedef struct force_array
{
 short fx;
 short fy;
 short fz;
 short mx;
 short my;
 short mz;
 short v1;
 short v2;
} force_array;

// SIX_AXIS_ARRAY
// Layout for the offsets and full scales.
typedef struct six_axis_array
{
 short fx;
 short fy;
 short fz;
 short mx;
 short my;
 short mz;
} six_axis_array;

// VECT_BITS
// Indicates which axis are to be used when computing the vectors. A vector
// is composed by 3 components and its "magnitude" is placed in V1 and V2.
// V1 defaults to a force vector and V2 defaults to a moment vector.
// Setting changeV1 or changeV2 will change that vector to be the opposite of
// its default.

// *** Check this norby ***
// This is badly defined at JR3 Manual. Correct definition follows:
typedef struct vect_bits
{
 unsigned fx : 1;
 unsigned fy : 1;
 unsigned fz : 1;
 unsigned mx : 1;
 unsigned my : 1;
 unsigned mz : 1;
 unsigned changeV1 : 1;
 unsigned changeV2 : 1;
 unsigned reserved : 8;
} vect_bits;

// WARNINGS
// Bit pattern for the warning word: xx_near_sat means that a near saturation
// has been reached or exceeded.
typedef struct warning_bits
{
 unsigned fx_near_sat : 1;
 unsigned fy_near_sat : 1;
 unsigned fz_near_sat : 1;
 unsigned mx_near_sat : 1;
 unsigned my_near_sat : 1;
 unsigned mz_near_sat : 1;
 unsigned reserved : 10;
} warning_bits;

// ERROR_BITS
// Bit pattern for the error word:
// 1. xx_sat means that a near saturation has been reached or exceeded.
// 2. memory_error indicates RAM memory error during power up.
// 3. sensor_change indicates that the sensor plugged in (different from the
//    original one) has passed CRC check. The user must reset this bit.
// 4. system_busyindicates system busy: transf. change, new full scale or new
//    sennsor plugged in.
// 5. cal_crc_bad means that it was a problem transmiting the calibration data
//    stored inside the sensor. If this bit does not come to zero 2s after the
//    sensor has been plugged in, there is a problem with the sensor's calibra-
//    tion data.
// 6. watch_dog2 indicates that sensor data and clock are being received.
// 7. watch_dog indicates that data line seems to be acting correctly.
// If either watch dog barks, the sensor data is not beig receive correctly.
typedef struct error_bits
{
 unsigned fx_sat : 1;
 unsigned fy_sat : 1;
 unsigned fz_sat : 1;
 unsigned mx_sat : 1;
 unsigned my_sat : 1;
 unsigned mz_sat : 1;
 unsigned reserved : 4;
 unsigned memory_error : 1;
 unsigned sensor_change : 1;
 unsigned system_busy : 1;
 unsigned cal_crc_bad : 1;
 unsigned watch_dog2 : 1;
 unsigned watch_dog : 1;
} error_bits;

// FORCE_UNITS
// Force_units is an enumerated value defining the different possible enginee-
// ring units used.
// 0 - lbs_in-lbs_mils -> lbs, inches * lbs and inches * 1000
// 1 - N_dNm_mmX10 -> Newtons, Newtons * meters * 10 and mm * 10
// 2 - kgF_kgFcm_mmX10 -> kilograms-Force, kilograms-Force * cm and mm * 10
// 3 - klbs_kin-lbs_mils -> 1000 lbs, 1000 inches * lbs and inches * 1000
typedef enum force_units
{
  lbs_in_lbs_mils,
  N_dNm_mmX10,
  kgF_kgFcm_mmX10,
  klbs_kin_lbs_mils,
  reserved_units_4,
  reserved_units_5,
  reserved_units_6,
  reserved_units_7
} force_units;

// THRESH_STRUCT
// This structure shows the layout for a single threshold packet inside of a
// load envelope. Each load envelope can contain several threshold structures.
// 1. data_address contains the address of the data for that threshold. This
//    includes filtered, unfiltered, raw, rate, counters, error and warning data
// 2. threshold is the is the value at which, if data is above or below, the
//    bits will be set ... (pag.24).
// 3. bit_pattern contains the bits that will be set if the threshold value is
//    met or exceeded.
typedef struct thresh_struct
{
 short data_address;
 short threshold;
 short bit_pattern;
} thresh_struct;

// LE_STRUCT
// Layout of a load enveloped packet. Four thresholds are showed ... for more
// see manual (pag.25)
// 1. latch_bits is a bit pattern that show which bits the user wants to latch.
//    The latched bits will not be reset once the threshold which set them is
//    no longer true. In that case the user must reset them using the reset_bit
//    command.
// 2. number_of_xx_thresholds specify how many GE/LE threshold there are.
typedef struct le_struct
{
 short latch_bits;
 short number_of_ge_thresholds;
 short number_of_le_thresholds;
 struct thresh_struct thresholds[4];
 short reserved;
} le_struct;

// LINK_TYPES
// Link types is an enumerated value showing the different possible transform
// link types.
// 0 - end transform packet
// 1 - translate along X axis (TX)
// 2 - translate along Y axis (TY)
// 3 - translate along Z axis (TZ)
// 4 - rotate about X axis (RX)
// 5 - rotate about Y axis (RY)
// 6 - rotate about Z axis (RZ)
// 7 - negate all axes (NEG)
typedef enum link_types
{
 end_x_form,
 tx,
 ty,
 tz,
 rx,
 ry,
 rz,
 neg
} link_types;

// TRANSFORM
// Structure used to describe a transform.

typedef struct links
{
 enum link_types link_type;
 short link_amount;
} links;

typedef struct transform
{
 struct links link[8];
} transform;

// JR3 force/torque sensor data definition. For more information see sensor and
// hardware manuals.
typedef struct force_sensor_data
{
 // Raw_channels is the area used to store the raw data coming from the sensor
 // See raw_channel struct definition
 struct raw_channel raw_channels[16];

 // JR3 copyright notice and reserved address 1
 short copyright[0x0018];
 short reserved1[0x0008];

 // Shunts contains the shunt readings. This is only used when the sensor
 // enables GAINS adjustments. Not used with this model, so its value must
 // read ALWAYS 0 (zero).
 struct six_axis_array shunts;
 short reserved2[2];

 // Default full scale: used when other full scale is not set by user.
 struct six_axis_array default_FS;
 short reserved3;

 // Load_envelope_num is the load envelope number that is currently in use.
 // This value is SET BY THE USER after one of the load envelops has been
 // initialized.
 short load_envelope_num;

 // Recommended minimum full scale (see manual pag.9).
 // This is the value at which the data will not saturate prematurely.
 struct six_axis_array min_full_scale;
 short reserved4;

 // Transform_num is the transform number that is currently in use. This value
 // is SET BY JR3 DSP after the user used command(5) ... see manual (pag.35).
 short transform_num;

 // Recommended maximum full scale (see manual pag.9).
 // This is the maximum value at which no resolution is lost.
 struct six_axis_array max_full_scale;
 short reserved5;

 // Address of the data that will be monitored by the peak routine.
 // This value is SET BY THE USER, to check the 8 contiguous addresses.
 short peak_address;

 // Current full scale used by the sensor (see manual page 10).
 // usually it is recommended to compromise in favor of resolution wich means
 // that the recommended maximum full scale SHOULD BE CHOSEN.
 struct force_array full_scale;

 // These are the sensor offsets. They are subtracted from the sensor data to
 // obtain the decoupled data (the output data will be then zero).
 // To set the future decoupled data to zero add this values to the current
 // decoupled data and place the the sum here.
 struct six_axis_array offsets;

 // This is the current offset. This is SET BY THE JR3 DSP ... (pag.10)
 short offset_num;

 // Bit map showing which of the axis are being used in the vector calculations
 // This value is SET BY THE JR3 DSP after ... (pag. 11)
 struct vect_bits vect_axes;

 // Unfiltered and decoupled data (i.e, with the offsets removed) from the
 // JR3 sensor
 struct force_array filter0;

 // Each of following arrays hold the filtered data. The decoupled data passes
 // trought a cascade of low pass filters, each having a cutoff frequency 1/4
 // of the succeeding filter. Filter 1 has a cutoff frequency of 1/16 of the
 // sample rate from the sensor: 500Hz for a typical sensor with a sample rate
 // of 8KHz. The rest of the filters would cutoff at 125Hz, 31.25Hz, 7.813Hz,
 // 1.953 Hz and 0.4883Hz.
 struct force_array filter1;
 struct force_array filter2;
 struct force_array filter3;
 struct force_array filter4;
 struct force_array filter5;
 struct force_array filter6;

 // Calculated rate data, first derivative calculation. Calculated at a
 // frequency specified by variable_rate_divisor and calculated on the data
 // specified by rate_address.
 struct force_array rate_data;

 // The following arrays hold the minimum and maximum (peak) data values.
 // The JR3 DSP monitors 8 contiguous data items for MIN and MAX values at full
 // sensor bandwidth. User  must request for area update. The address of the
 // data to watch for peaks is specified by peak_address.
 // Peak data is lost when executing coordinate transformation, full scale
 // change and when a new sensor is plugged in.
 struct force_array minimum_data;
 struct force_array maximum_data;

 // This values are used to determine if the raw sensor is satureted. The decou-
 // pling process (offset removal) makes it difficult to say from the processed
 // data if the sensor is saturated. Also watch for error and warning words.
 // This values may be SET BY THE USER, and the defaults are:
 // 80% of ADC full scale for near_sat_value (26214) and
 // ADC ful scale for sat_value (32768 - 2^(16 - ADC bits)).
 short near_sat_value;
 short sat_value;

 // Definition for rate calculations:
 // Rate_address - address of data used for calculations (8 contiguous)
 // Rate_divisor - Determines how often rate is calculated: 1 for rate
 //                calculation at full sensor bandwith, 0 for calculation
 //                every 65536 samples ... (100 for calc. every 100 samples)
 // Rate count   - Counts from zero until rate_divisor, at wich the rate is
 //					 calculated: rate_count resets then to zero and ...
 // Hint: When setting new rate_divisor set rate_count to rate_divisor-1. This
 // will speed up the begeening of rate calculations.
 short rate_address;
 unsigned short rate_divisor;
 unsigned short rate_count;

 // These areas are used to send commands to the JR3 DSP. The DSp answers with
 // a zero (0) when the command was successful and with a negative value to
 // indicate an error.
 short command_word2;
 short command_word1;
 short command_word0;

 // These values are incremented every time the matching filters are calculated.
 // These values can be used to wait for data, i.e, the user should read data
 // after count change to ensure that he reads data just once.
 unsigned short count1;
 unsigned short count2;
 unsigned short count3;
 unsigned short count4;
 unsigned short count5;
 unsigned short count6;

 // This value counts data reception errors. If it is changing rapidly it means
 // that there is some hardware or cabling error. In normal situation it should
 // not change at all. It is nevertheless possible to have some activity in
 // EXTREMELY NOISY environments: in those cases (not meaning hardware problems)
 // the sampled data is ignored.
 unsigned short error_count;

 // When the JR3 DSP searches it job queue and find nothing to do this counter
 // is incremented. it is an indication of the amount of time the DSP was
 // available (doing nothing). It can also be used to see if the DSP is alive.
 unsigned short count_x;

 // Warnings and errors contain the warning and error bits ... (pag. 22)
 struct warning_bits warnings;
 struct error_bits errors;

 // Contains the bits that are set by the load envelops ... (pages 17 & 22)
 short threshold_bits;

 // Actual calculated CRC. It should be zero ... (pag. 22)
 short last_crc;

 // EEPROM number and software version
 short eeprom_ver_no;
 short software_ver_no;

 // Release date of the software: day of the year from 1 (1/1) to 365 (31/12) for
 // non leap years.
 short software_day;
 short software_year;

 // Serial number and model number: they identify the sensor. Actually the model
 // number does not correspond to JR3 model number but provides a unique
 // identifier for different sensor configurations.
 unsigned short serial_no;
 unsigned short model_no;

 // Calibration date: day from 1 (1/1) to 366 (31/12) for leap years.
 short cal_day;
 short cal_year;

 // Units defines the units used in this sensor full scale.
 enum force_units units;

 // Number of bits of the ADC currently in use.
 short bits;

 // Bit field that specifies the channels the current sensor can send.
 short channels;

 // Specifies the overall thickness of the sensor.
 short thickness;

 // Table containing the load envelope descriptions. See le_struct ... (pag. 25)
 struct le_struct load_envelopes[0x10];

 // Table containing the transform descriptions. See transform struct (pag.28).
 struct transform transforms[0x10];
} force_sensor_data;

// Note about addressing, reading and writing to/from the DSP space.
// There are 2 two-byte word registers for address and data.
// Address register: base_address + 0 and base_address + 1.
// Data register: base_address + 2 and base_address + 3.


// Read data from JR3
// Input parameter: address, processor number
// Return Value: Value stored at address
short read_jr3(unsigned short, short, short);

// Write data to JR3
// Input parameters: address, value_to_write, processor number
void write_jr3(unsigned short, unsigned short, short, short);

// Command JR3
// Input parameters: address, value_to_write, processor number
// Return Value: 0 if command was sucessful
short command_jr3(unsigned short, unsigned short, short, short);

// Reads System Warnings
// Input parameters: processor number
// Return Value: warning info in a f_m_saturation format
struct f_m_saturation system_warnings(short, short);

// Reads System Errors (all)
// Input parameters: processor number
// Return Value: error info in a error_bits format
struct error_bits system_errors(short, short);

// Reads Saturation Errors
// Input parameters: processor number
// Return Value: saturation errors info in a f_m_saturation format
struct f_m_saturation saturation(short, short);

//** Individual relevant error bits **********************

// Checks System Busy
// Input parameters: processor number
short system_busy(short,short);

// Checks Memory Error
// Input parameters: processor number
short system_memory_error(short,short);

// Checks Sensor Change
// Input parameters: processor number
short system_sensor_change(short,short);

// Checks Cal_Crc_Bad
// Input parameters: processor number
short system_cal_crc_bad(short,short);

// Checks Watch_Dog2
// Input parameters: processor number
short system_watch_dog2(short,short);

// Checks Watch_Dog
// Input parameters: processor number
short system_watch_dog(short,short);

//********************************************************

// Set Vector Axes
// Input Value: Bit_pattern, processor number
// Return Value: 0 if command was successful
short set_vect(short,short,short);

// ** NOT USED IN THIS VERSION **
// Prepares envelope to be used
// Return Value: 0 if command was successful
short prepare_use_envelope(unsigned short, unsigned short,short,short);

// Gets Treshold Status
// Return Value: 0 if command was successful
short get_threshold_status(short,short);

// Reset Treshhold bits
// Input parameters: processor number
void reset_threshold_bits(short,short);

// Set Transforms
// Input parameters: transform struct, transform num, processor number
// Return Value: 0 if command was successful
short set_transforms(struct transform, short,short,short);

// Use Transform
//Input parameters: transform num, processor number
// Return Value: 0 if command was successful
short use_transform(short,short,short);

// Read force/torque data
// Input parameters: filter address, processor number
// Return Value: F/T data in a force_array format
struct force_array read_ftdata(short,short,short);
                       	                                               
// Read Current offsets
// Input parameters: processor number
// Return Value: Offset info in a six_axis_array format
struct six_axis_array read_offsets(short,short);

// Set offsets (function 1)
// Input parameters: New offsets in a six_axis_array format, processor number
// Return Value: 0 if command was successful
short set_offsets(struct six_axis_array,short,short);


// Reset offsets with values of FILTER2
// Input parameters: processor number
// Return Value: 0 if command was successful
short reset_offsets(short,short);

// Change Offset_Num
// Input parameter: Offset num, processor number
// Return Value: 0 if command was successful
short change_offset_num(short,short,short);

// Use Offset
// Input parameter: Offset num, processor number
// Return Value: 0 if command was successful
short use_offset(short,short,short);

// Set address to watch for peaks 
// Input parameters: filter address, processor number
// Return value: 0 if command was successful
short peak_data(short,short,short);

// Set address to watch for peaks and resets internal values to current data
// Input parameters: filter address, processor number
// Return value: 0 if command was successful
short peak_data_reset(short,short,short);

// Read Peak Data
// Input parameters: (0) for Minimum and (1) for Maximum, processor number
// Return Value: Peak data in a force_array format
struct force_array read_peaks(short,short,short);

// Read Actual Full-Scales
// Input parameters: processor number
// Return Value: Full Scales in a sis_axis_array format
struct force_array get_full_scales(short,short);

// Read Recommended Full-Scales (defining MIN_F_S or MAX F_S)
// Input Value: MIN_F_S or MAS_F_S
// Return Value: Recommended Full Scales in a sis_axis_array format
struct six_axis_array get_recommended_full_scales(short,short,short);

// Set JR3 Full_Scales
// Input Value: New Full Scales in a six_axis_array format, processor number
// Return Value: 0 if command was successful
short set_full_scales(struct six_axis_array,short,short);


// Change bits in a word placed in JR3 DSP memory
// Input values: bitmap_value, bitmap_address
// Return Value: 0 if command was successful
short bit_set(short,short,short,short);


// Input Values: vendor_ID, device_ID, number_of_board, number_of_processors, download
// where 
// number_of_board = 1 to single board system
// number_of_processors is the number of processors in the board (1 for simple PCI boards)
// download is a value that should be 1 (if code is to be downloaded) or any other value 
// if code was already download and user wants only to open an handle to the board.

// Return Values:
// 0: if running under Windows_NT
// 1: If running under Windows_95
// 2: If running under Windows_311 with win32s
// 3: if running under other operating system -> ERROR: STOP OPERATION.

// -91: Failled to open Handle to Windriver ... run wdreg
// -92: Windriver version error
// -93: PCI Card Not Found
// -94: Card Not In Range
// -95: Failed Locking PCI Card (already in use)
// -96: Download Error

short init_jr3(unsigned long, unsigned long, unsigned long, short, short, short);

// Removes the environment
void close_jr3(short);



// (c) J. Norberto Pires Robotics and Control Laboratory 1997-2001
// norberto@robotics.dem.uc.pt
// http://robotics.dem.uc.pt/norberto/
