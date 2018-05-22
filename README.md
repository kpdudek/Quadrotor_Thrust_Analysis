# ATI_Log_Processor

Matlab functions that process the data from the PixHawk and ATI Force Torque sensor to find the coefficient of thrust of the motors


# Usage

1. In POC_tracks_alignment.m type in the csv filename to read from on line 2, and the filename that the output will be saved to   in line 44
2. Run POC_tracks_alignment.m

3. In POCidentification.m type in the .mat filename from step 1.
4. Run POCidentification.m


POCidentification.m outputs three sets of solutions separated by the headers "Linear system solution", "Averaging solution", and "Independent Values"

The "Linear system solution" uses matlabs backslah operator to solve the large matricies with all data points while the "averaging solution" takes the average value of each variable and then solves for the coefficient matrix.

"Independent values" solves for the coefficent of thrust for each motor rather than assuming a constant value througout the quad
