/**
 *  Copyright (C) 2026, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <https://www.gnu.org/licenses/> for a copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: ECP5U to ECP5UM FPGA uncompressed bitstream device id
 *               conversion.
 *
 *  Scans ECP5U FPGA bitstream for the ECP5U device id and replace it by an
 *  EPC5UM device id. Recalculates the CRC16-BUYPASS (polynomial 0x8005, no bit
 *  reversal). See Lattice FPGA-TN-02039 ECP5 and ECP5-5G sysCONFIG User Guide,
 *  appendix B, ECP5 and ECP5-5G Uncompressed Bitstream Format Technical Note.
 */

// ---- include files ----
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define ECP5U_ID    0x41
#define ECP5UM_ID   0x01
#define ECP5U_25_ID 0x10
#define ECP5U_45_ID 0x20
#define ECP5U_85_ID 0x30

typedef unsigned char  BYTE;
typedef unsigned short U16;
typedef unsigned int   U32;
typedef struct {
    U16  configFrames;
    U16  dataBitsFrame;
} sECP5_DEVICE;

/*============================================================================*/
U16 crc16( U16 crc, BYTE byte ) {
/*============================================================================*/
    U16  msb_flag;
    BYTE bit;

    crc ^= ((U16)byte << 8 );

    for ( bit = 0; bit < 8; bit++ ) {
        msb_flag = crc & 0x8000;
        crc <<= 1;

        if ( msb_flag ) crc ^= 0x8005;
    }

    return crc;
}

BYTE preamble[8] = { 0xFF, 0xFF, 0xBD, 0xB3, 0xFF, 0xFF, 0xFF, 0xFF };
BYTE reset_crc_cmd[4] = { 0x3B, 0x00, 0x00, 0x00 }; // Reset CRC, start of CRC calculation
BYTE verify_id_cmd[4] = { 0xE2, 0x00, 0x00, 0x00 };
BYTE prog_inc_rti_cmd[4] = { 0x82, 0x91, 0x00, 0x00 };
BYTE program_done_cmd[8] = { 0x5E, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF }; // Program done + dummy frame, end of bitstreasm
BYTE device_id[4] = { ECP5U_ID, 0x11, ECP5U_25_ID, 0x43 };
BYTE dummy_frame[4] = { 0xFF, 0xFF, 0xFF, 0xFF };
sECP5_DEVICE ecp5Device = { 0, 0 };

/*============================================================================*/
int main(int argc, char** argv)
/*============================================================================*/
{
    BYTE byteRd = 0;
    BYTE buffer[8];
    BYTE i = 0;
    BYTE listFrames = 0;
    BYTE bLine = 0;
    BYTE bPrint = 0;
    BYTE bPreamble = 0;
    char text[17]; // + string delimeter
    U16 crcCommands = 0;
    int filePos = 0;
    int filePosFrameSize = 0;
    int filePosCrcCheck = 0;
    int bufferCrcMask = -1; // All 1's
    int printCrc = -1;
    int crcNbBytes = 0;
    int nbFrames = 0;
    int printCrcNbBytes = 0;
    FILE* pFile = NULL;

    if (( 3 == argc ) && ( '-' == argv[2][0] ) && ( 'p' == argv[2][1] )) {
        bPrint = 1;
        listFrames = (BYTE)argv[2][2];

        if (( listFrames >= '1' ) && ( listFrames <= '9' )) {
            listFrames = listFrames - '0';
        } else {
            listFrames = 0;
        }
    } else if ( argc != 2 ) {
        printf( "Usage: %s <file> [-p[1..9]]!", argv[0] );
        return 0;
    }

    pFile = fopen( argv[1], "rb+" );
    if ( NULL == pFile ) {
        printf( "%s could not open %s!", argv[0], argv[1] );
        return 0;
    }

    memset( buffer, 0, sizeof( buffer ));
    memset( text, 0, sizeof( text ));

    while ( fread( &byteRd, 1, 1, pFile ) == 1 ) {
        filePos++;

        memcpy( &buffer[0], &buffer[1], 7 );
        buffer[7] = byteRd;

        if ( bPrint ) {
            i = filePos % 16;

            bLine = (BYTE)( i == 0 );

            if ( bLine ) {
                i = 15;
            } else {
                i = i - 1;
            }

            if ( byteRd >= 0x20 ) { // >= SPACE
                if ( byteRd >= 0x80 ) { // > ASCII 127
                    text[i] = ' ';
                } else {
                    text[i] = byteRd;
                }
            } else {
                text[i] = '.';
            }

            printf( "%02X", byteRd );

            if ( bLine ) {
                printf( "  %s", text );

                if ( printCrc >= 0 ) {
                    printf( "  %04X +%d", printCrc, printCrcNbBytes );
                    printCrc = -1;
                }

                printf( "\n" );
            } else if ( i & 1 ) {
                printf( " " ); // Space
            }
        }

        if ( !bPreamble && ( memcmp( &buffer[0], preamble, sizeof( preamble )) == 0 )) {
            bPreamble = 1;
        } else if ( !ecp5Device.configFrames ) {

            if ( memcmp( &buffer[0], reset_crc_cmd, sizeof( reset_crc_cmd )) == 0 ) {
                crcCommands = 0;
                printCrc = 0;
            }

            if ( memcmp( &buffer[0], verify_id_cmd, sizeof( verify_id_cmd )) == 0 ) {
                // Check ECP5UM id
                if ((( ECP5UM_ID == buffer[4] ) || ( ECP5U_ID == buffer[4] )) && ( device_id[1] == buffer[5] )) {
                    if ( device_id[3] == buffer[7] ) {
                        if ( ECP5U_25_ID == buffer[6] ) {
                            device_id[2] = ECP5U_25_ID;
                            ecp5Device.configFrames = 7562;
                            ecp5Device.dataBitsFrame = 592;
                        } else if ( ECP5U_45_ID == buffer[6] ) {
                            device_id[2] = ECP5U_45_ID;
                            ecp5Device.configFrames = 9470;
                            ecp5Device.dataBitsFrame = 848;
                        } else if ( ECP5U_85_ID == buffer[6] ) {
                            device_id[2] = ECP5U_85_ID;
                            ecp5Device.configFrames = 13294;
                            ecp5Device.dataBitsFrame = 1136;
                        }
                    }
                }

                if ( !ecp5Device.configFrames ) {
                    printf( "Device ID mismatch!\n" );
                    return 0;
                } else if (( !bPrint ) && ( ECP5U_ID == buffer[4] )) {
                    buffer[4] = ECP5UM_ID;
                    device_id[0] = ECP5UM_ID;
                    fseek( pFile, ( filePos - 4 ), SEEK_SET );
                    fwrite( &device_id[0], 1, 1, pFile ); // Convert device id!
                    fseek( pFile, filePos, SEEK_SET );
                }

                prog_inc_rti_cmd[2] = (BYTE)( ecp5Device.configFrames >> 8 );
                prog_inc_rti_cmd[3] = (BYTE)( ecp5Device.configFrames & 0xFF );
                crcNbBytes = 0;
            }
        }

        if ( filePosCrcCheck && ( filePos == filePosCrcCheck )) {
            bufferCrcMask = 0xFC; // Unmask CRC!
            filePosCrcCheck = filePos + filePosFrameSize + 3; // CRC + dummy byte
        } else if ( memcmp( &buffer[0], prog_inc_rti_cmd, sizeof( prog_inc_rti_cmd )) == 0 ) {
            filePosFrameSize = ecp5Device.dataBitsFrame >> 3;
            filePosCrcCheck = filePos + filePosFrameSize + sizeof( prog_inc_rti_cmd );
        }

        if ( memcmp( &buffer[0], program_done_cmd, sizeof( program_done_cmd )) == 0 ) {
            break; // Leave while loop!
        } else if ( ecp5Device.configFrames && ( bufferCrcMask & 1 )) {
            // CRC starts with verify_id command
            crcCommands = crc16( crcCommands, buffer[0] );
            crcNbBytes++;
        } else if ( 0xFF == buffer[2] ) { // Check dummy byte/frame

            if ( crcNbBytes ) {
                nbFrames++;
                // Update CRC?
                if ( !bPrint && ( 1 == nbFrames ) && ( ECP5UM_ID == device_id[0] )) {
                    BYTE* pCrc = (BYTE*)&crcCommands + 1;
                    fseek( pFile, ( filePos - 8 ), SEEK_SET );
                    fwrite( pCrc, 1, 1, pFile ); // Update CRC high byte!
                    fwrite( --pCrc, 1, 1, pFile ); // Update CRC low byte!
                    fseek( pFile, filePos, SEEK_SET );
                }

                if ( nbFrames && ( nbFrames != ecp5Device.configFrames )) {
                    printCrc = crcCommands;
                    crcCommands = 0; // CRC Reset
                    printCrcNbBytes = crcNbBytes;
                    crcNbBytes = 0;
                }
            }
        } else if ( listFrames && ( listFrames == nbFrames )) {
            break; // Leave while loop!
        }

        bufferCrcMask = ( bufferCrcMask >> 1 ) | 0x80; // Mask buffer[7]
    }

    if ( bPrint ) {

        if ( !bLine ) {
            text[i+1] = '\0';
            printf( "  %s\n", text );
        }

        printf( "\nconfigFrames = %d\ndataBitsFrame = %d\n", ecp5Device.configFrames, ecp5Device.dataBitsFrame );
    }

    (void)fclose( pFile );

    return 0;
}
