const std = @import("std");
const lib = @import("infra");
const Event = @import("events.zig").Event;
const EventTag = std.meta.Tag(Event);

const EntityID = @import("entity.zig").EntityID;
const damage = @import("damage.zig");
const stats = @import("stats.zig");
const World = @import("world.zig").World;

const cards = @import("cards.zig");
const Instance = cards.Instance;
const Template = cards.Template;
const card_list = @import("card_list.zig");
const BeginnerDeck = card_list.BeginnerDeck;
const slot_map = @import("slot_map.zig");
const SlotMap = slot_map.SlotMap;

pub const Deck = struct {
    alloc: std.mem.Allocator,
    entities: SlotMap(*Instance),   // EntityID provider
    deck: std.ArrayList(*Instance), // all cards 
    draw: std.ArrayList(*Instance), // draw pile
    hand: std.ArrayList(*Instance), // (player) hand
    exhaust: std.ArrayList(*Instance), // exhausted cards
    techniques: std.StringHashMap(*const cards.Technique),

    pub fn init(alloc: std.mem.Allocator, templates: []const Template) !@This() {
        var self = @This(){
            .alloc = alloc,
            .entities = try SlotMap(*Instance).init(alloc),
            .deck = try std.ArrayList(*Instance).initCapacity(alloc, templates.len),
            .draw = try std.ArrayList(*Instance).initCapacity(alloc, templates.len),
            .hand = try std.ArrayList(*Instance).initCapacity(alloc, templates.len),
            .exhaust = try std.ArrayList(*Instance).initCapacity(alloc, templates.len),
            .techniques = std.StringHashMap(*const cards.Technique).init(alloc),
        };
        // NOTE: this *t is important because we need a stable reference to the static template - using t in the 
        // for loop and then taking a pointer will yield a copy!
        for (templates) |*t| {
            for (t.rules) |rule| {
                for (rule.expressions) |expr| {
                    switch(expr.effect) {
                        .combat_technique => |value| {
                           if(self.techniques.get(value.name) == null) {
                               try self.techniques.put(value.name, &value);
                           }
                        },
                        else => {},
                    }
                }
            }
            // TODO: weight these by some kind of ... weight ... and randomize creation of instances for starter deck
            for (0..3) |_| {
                try self.deck.append(alloc, try self.createInstance(t));
            }
        }
        return self;
    }
    
    pub fn deinit(self: *Deck) void {
        // Free all allocated instances
        for (self.entities.items.items) |instance| {
            self.alloc.destroy(instance);
        }
        self.entities.deinit();
        self.deck.deinit(self.alloc);
        self.draw.deinit(self.alloc);
        self.hand.deinit(self.alloc);
        self.exhaust.deinit(self.alloc);
        self.techniques.deinit();
    }

    fn createInstance(self: *Deck, template: *const Template) !*Instance {
        var instance = try self.alloc.create(Instance);
        std.debug.print("insert: {s}", .{template.name});
        instance.template = template;
        std.debug.print(" -- insert: {s}\n", .{instance.template.name});
        const id: EntityID = try self.entities.insert(instance);
        instance.id = id;
        return instance;
    }
};

