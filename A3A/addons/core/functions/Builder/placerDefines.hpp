#define	SPACE_PRESSED	0
#define	ROTATION_MODE_CW	1
#define	ROTATION_MODE_CCW	2
#define	GUI_BUTTON_PRESSED	3
#define	UNSAFE_MODE	4
#define	BUILD_OBJECTS_ARRAY	5
#define	BUILD_OBJECT_SELECTED_STRING	6
#define	BUILD_OBJECT_TEMP_OBJECT	7
#define	BUILD_OBJECT_TEMP_OBJECT_ARRAY	8
#define	END_BUILD_FUNC	9
#define	BUILD_DISPLAY	10
#define	KEY_DOWN_EH	11
#define	KEY_UP_EH	12
#define	EACH_FRAME_EH	13
#define	UPDATE_BB	14
#define	BUILD_RADIUS_OBJECT_CENTER	15
#define	BUILD_RADIUS	16
#define	HOLD_TIME	17
#define	OBJECT_PRICE	18
#define BUILD_OBJECT_TEMP_DIR 19
#define TEAMLEADER_BOX 20
#define ELEVATION_MODE_UP 21
#define ELEVATION_MODE_DOWN 22
#define SNAP_SURFACE_MODE 23
#define AVAILABLE_MONEY 24
#define CURSOR_OBJECT 25

// Building budget a construction kit gives per euro of its purchase price.
// Refunds and the kit's resale value divide by it again, so the extra budget can't be cashed out.
#define BUILD_BUDGET_MULTIPLIER 6

// Unbuilt constructions build themselves after this long, scaled linearly by price up to AUTO_BUILD_PRICE_CAP
#define AUTO_BUILD_TIME_MIN 300
#define AUTO_BUILD_TIME_MAX 1800
#define AUTO_BUILD_PRICE_CAP 3000
