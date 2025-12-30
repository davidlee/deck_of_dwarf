pub const Config = struct {
    fps: usize,
    width: usize,
    height: usize,
    logical_width: usize,
    logical_height: usize,

    pub fn init() @This() {
        return @This(){
            .fps = 60,
            .width = 1920,
            .height = 1080,
            .logical_width = 1920,
            .logical_height = 1080,
        };
    }
};
