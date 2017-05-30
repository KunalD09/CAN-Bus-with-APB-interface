//definition for the frame request type


package cantidef;

typedef enum [1:0] { XMITdataframe,XMITremoteframe,XMITerrorframe,
    XMIToverloadframe } xmitFrameType;

endpackage : cantidef
