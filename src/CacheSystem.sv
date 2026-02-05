`timescale 1ns / 1ps

module CacheSystem (
    input wire clk,
    input wire reset,
    
    // پورت‌های سمت پردازنده
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire mem_read,
    input wire mem_write,
    input wire [2:0] mask,
    output reg [31:0] rdata,
    output reg hit
);

    // =========================================================
    // تنظیمات کش: Direct Mapped, 64 Lines, 1 Word per Line
    // =========================================================
    reg [31:0] cache_data  [0:63];  // ذخیره داده (256 بایت)
    reg [23:0] cache_tag   [0:63];  // ذخیره تگ
    reg        cache_valid [0:63];  // بیت اعتبار

    // تفکیک آدرس
    wire [5:0]  index = addr[7:2];    // ایندکس برای انتخاب خط (0 تا 63)
    wire [23:0] tag   = addr[31:8];   // تگ برای مقایسه

    // =========================================================
    // ارتباط با حافظه اصلی (Main Memory)
    // =========================================================
    wire [31:0] mem_rdata;
    
    // در روش Write-Through، هر وقت نوشتن داریم، به حافظه اصلی هم می‌فرستیم
    MainMemory main_mem (
        .clk(clk),
        .addr(addr),
        .wdata(wdata),
        .mem_write(mem_write), // همیشه نوشتن را به حافظه اصلی پاس می‌دهیم
        .mem_read(mem_read),   // خواندن را هم پاس می‌دهیم (برای زمانی که Miss شود)
        .rdata(mem_rdata)
    );

    // =========================================================
    // منطق تشخیص Hit/Miss
    // =========================================================
    wire valid_bit = cache_valid[index];
    wire [23:0] stored_tag = cache_tag[index];
    wire tag_match = (stored_tag == tag);

    always @(*) begin
        // فقط زمانی Hit داریم که بیت اعتبار 1 باشد و تگ‌ها یکی باشند
        if ((mem_read || mem_write) && valid_bit && tag_match)
            hit = 1'b1;
        else
            hit = 1'b0; // Miss
    end

    // =========================================================
    // خواندن داده (Read Logic)
    // =========================================================
    reg [31:0] raw_data;

    always @(*) begin
        if (mem_read) begin
            if (hit) begin
                // اگر Hit شد، از کش می‌خوانیم
                raw_data = cache_data[index];
            end else begin
                // اگر Miss شد، داده‌ای که از MainMemory آمده را استفاده می‌کنیم
                // (در واقعیت اینجا باید پردازنده Stall شود، اما برای سادگی داده را عبور می‌دهیم)
                raw_data = mem_rdata; 
            end

            // اعمال Mask (برای دستورات lb, lh, lw)
            case (mask)
                3'b000: begin // lb (Byte Signed)
                    case (addr[1:0])
                        2'b00: rdata = {{24{raw_data[7]}},   raw_data[7:0]};
                        2'b01: rdata = {{24{raw_data[15]}},  raw_data[15:8]};
                        2'b10: rdata = {{24{raw_data[23]}},  raw_data[23:16]};
                        2'b11: rdata = {{24{raw_data[31]}},  raw_data[31:24]};
                    endcase
                end
                3'b001: begin // lh (Half Signed)
                    case (addr[1])
                        1'b0: rdata = {{16{raw_data[15]}},  raw_data[15:0]};
                        1'b1: rdata = {{16{raw_data[31]}},  raw_data[31:16]};
                    endcase
                end
                3'b010: begin // lw (Word)
                    rdata = raw_data;
                end
                3'b100: begin // lbu (Byte Unsigned)
                    case (addr[1:0])
                        2'b00: rdata = {24'b0, raw_data[7:0]};
                        2'b01: rdata = {24'b0, raw_data[15:8]};
                        2'b10: rdata = {24'b0, raw_data[23:16]};
                        2'b11: rdata = {24'b0, raw_data[31:24]};
                    endcase
                end
                default: rdata = 32'b0;
            endcase
        end else begin
            rdata = 32'b0;
        end
    end

    // =========================================================
    // نوشتن و آپدیت کش (Write & Update Logic)
    // =========================================================
    integer i;
    always @(negedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<64; i=i+1) cache_valid[i] <= 1'b0;
        end
        else begin
            // 1. اگر Miss در خواندن داشتیم -> داده را از حافظه به کش بیاور (Allocation)
            if (mem_read && !hit) begin
                cache_valid[index] <= 1'b1;
                cache_tag[index]   <= tag;
                cache_data[index]  <= mem_rdata; // داده از MainMem به Cache
            end
            
            // 2. اگر نوشتن داشتیم (Write-Through)
            // ما هم در حافظه اصلی می‌نویسیم (توسط ماژول MainMemory)
            // هم اگر در کش موجود بود، آپدیتش می‌کنیم.
            // (یا حتی اگر نبود هم می‌توانیم آپدیت کنیم - Write Allocate)
            if (mem_write) begin
                // اینجا فرض می‌کنیم همیشه کش را هم آپدیت می‌کنیم (ساده‌ترین حالت)
                cache_valid[index] <= 1'b1;
                cache_tag[index]   <= tag;
                
                // باید فقط بایت‌های خاصی را تغییر دهیم، پس اول داده فعلی را میخوانیم
                // توجه: در شبیه‌سازی دقیق سخت‌افزاری این بخش پیچیده‌تر است.
                // اینجا فرض می‌کنیم wdata کل کلمه است یا لاجیک ماسک را ساده می‌کنیم.
                // برای این پروژه درسی، فرض میکنیم در Store Word کل کلمه نوشته میشود.
                if (mask == 3'b010) begin // SW
                     cache_data[index] <= wdata;
                end
                // برای SB و SH چون پیچیده می‌شود، فعلا کش را Invalid می‌کنیم تا از حافظه اصلی بخواند
                else begin
                     cache_valid[index] <= 1'b0; 
                end
            end
        end
    end

endmodule
