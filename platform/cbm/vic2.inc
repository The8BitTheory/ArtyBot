; vic2.inc - VIC-II-Register (C64, C128 im 40-Zeichen-Modus, MEGA65 im VIC-II-Modus)

VIC_SPR0X   = $D000
VIC_SPR0Y   = $D001
VIC_SPR1X   = $D002
VIC_SPR1Y   = $D003
VIC_SPRXMSB = $D010
VIC_CTRL1   = $D011
VIC_RASTER  = $D012
VIC_SPR_EN  = $D015
VIC_CTRL2   = $D016
VIC_SPR_EXPY= $D017
VIC_MEMPTR  = $D018
VIC_IRR     = $D019
VIC_IMR     = $D01A
VIC_SPR_PRI = $D01B
VIC_SPR_MC  = $D01C
VIC_SPR_EXPX= $D01D
VIC_BORDER  = $D020
VIC_BG0     = $D021
VIC_BG1     = $D022
VIC_BG2     = $D023
VIC_SPR_MC0 = $D025         ; shared sprite multicolour 1 (%01)
VIC_SPR_MC1 = $D026         ; shared sprite multicolour 2 (%11)
VIC_SPR0COL = $D027

COLORRAM    = $D800

RASTER_LINE = 250           ; raster IRQ line (below the text area, PAL)
