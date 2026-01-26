#!/usr/bin/env python
# fpga_route_gui.py  –  XC6SLX75 “draw a route ⇒ Verilog” prototype with segments
#                     and perfect per-square hit testing
#
#  ▸ Requires:  pip install PyQt6
#  ▸ Tested on: Python 3.10 / 3.11 / 3.12  (Windows 10)
#
#  Launch:  python fpga_route_gui.py
#           (shows the flipped-Y grid; “New Segment”, intermediates, Undo, perfect clicks)


import os
import re
import sys
import pathlib
import textwrap
from collections import namedtuple

from PyQt6.QtCore    import Qt, QPointF, QRectF
from PyQt6.QtGui     import QPen, QBrush, QPainter, QTransform
from PyQt6.QtWidgets import (
    QApplication, QFileDialog, QGraphicsScene, QGraphicsView,
    QGraphicsRectItem, QGraphicsLineItem, QMainWindow,
    QMessageBox, QPushButton, QToolBar, QComboBox
)


# ── CONFIG ───────────────────────────────────────────────────────────────
script_dir   = pathlib.Path(__file__).parent.resolve()
XDLRC_PATH     = script_dir / "xc6slx75-csg484-2.xdlrc"
GRID_SIZE      = 6
LINE_PEN       = QPen(Qt.GlobalColor.cyan, 2)
NODE_BRUSH     = QBrush(Qt.GlobalColor.darkGray)
SLICE_PEN      = QPen(Qt.GlobalColor.lightGray, 0.5)
SELECT_BRUSH   = QBrush(Qt.GlobalColor.red)
INTER_BRUSH    = QBrush(Qt.GlobalColor.green)


Slice = namedtuple("Slice", "x y name")



# ── DEVICE PARSER ────────────────────────────────────────────────────────
class Device:
    SLICE_PAT = re.compile(r"SLICE_X(\d+)Y(\d+)", re.IGNORECASE)


    def __init__(self, path):
        if not os.path.exists(path):
            raise FileNotFoundError(path)
        self.slices = []
        self._scan(path)
        if not self.slices:
            raise RuntimeError("No slices in XDLRC")
        # normalize
        minx = min(s.x for s in self.slices)
        miny = min(s.y for s in self.slices)
        self.slices = [Slice(s.x-minx, s.y-miny, s.name) for s in self.slices]


    def _scan(self, fn):
        seen = set()
        with open(fn, "r", encoding="latin1", errors="ignore") as f:
            for L in f:
                m = self.SLICE_PAT.search(L)
                if not m: continue
                x,y = map(int, m.groups())
                if (x,y) in seen: continue
                seen.add((x,y))
                self.slices.append(Slice(x, y, f"SLICE_X{x}Y{y}"))



# ── SCENE ────────────────────────────────────────────────────────────────
class DeviceScene(QGraphicsScene):
    def __init__(self, dev: Device):
        super().__init__()
        self.dev               = dev
        self.intermediate_count= 0
        self.parallel_wires    = 1
        self.slice_items       = {}   # (x,y) -> QGraphicsRectItem
        self.item_to_logical   = {}   # QGraphicsRectItem -> (x,y)
        self.segments          = []   # list of {display_points, logical_points, line_items}
        self._draw_device()
        self.new_segment()


    def _draw_device(self):
        """Draw all slices, store both mappings."""
        maxy = max(s.y for s in self.dev.slices)
        for s in self.dev.slices:
            x0 = s.x * GRID_SIZE
            y0 = (maxy - s.y) * GRID_SIZE
            R = QRectF(x0, y0, GRID_SIZE, GRID_SIZE)
            item = QGraphicsRectItem(R)
            item.setPen(SLICE_PEN); item.setBrush(NODE_BRUSH)
            self.addItem(item)
            self.slice_items[(s.x, s.y)] = item
            self.item_to_logical[item]   = (s.x, s.y)


    def new_segment(self):
        self.segments.append({
            'disp': [], 'log': [], 'lines': []
        })


    def set_intermediate_count(self, n: int):
        self.intermediate_count = n
        
    def set_parallel_wires(self, n: int):
        self.parallel_wires = n
        


    def mousePressEvent(self, ev):
        if ev.button() != Qt.MouseButton.LeftButton:
            return
        seg = self.segments[-1]


        # 1) hit-test exact slice under cursor
        pos = ev.scenePos()
        item = self.itemAt(pos, QTransform())
        if not isinstance(item, QGraphicsRectItem) or item not in self.item_to_logical:
            return    # click outside any slice square
        lx, ly = self.item_to_logical[item]


        maxy = max(s.y for s in self.dev.slices)
        maxx = max(s.x for s in self.dev.slices)  # New line: Add this
        # 2) handle intermediates from previous to this
        if seg['log']:
            px, py = seg['log'][-1]
            n = self.intermediate_count
            for i in range(1, n+1):
                t   = i/(n+1)
                mix = round(px + t*(lx-px))
                miy = round(py + t*(ly-py))
                # Original: mix = max(0, min(mix, max(s.x for s in self.dev.slices)))
                # Updated:
                mix = max(0, min(mix, maxx))
                miy = max(0, min(miy, maxy))
                if (mix,miy) in seg['log']: continue
                # New lines: Add this block
                if (mix, miy) not in self.slice_items:
                    print(f"Warning: Skipping invalid intermediate slice ({mix}, {miy}) - no such location exists.")
                    continue
                # color green
                itm = self.slice_items[(mix,miy)]
                itm.setBrush(INTER_BRUSH)
                # draw line
                last_dp = seg['disp'][-1]
                dpx = mix*GRID_SIZE + GRID_SIZE/2
                dpy = (maxy-miy)*GRID_SIZE + GRID_SIZE/2
                line = self.addLine(last_dp.x(), last_dp.y(), dpx, dpy, LINE_PEN)
                seg['lines'].append(line)
                dp = QPointF(dpx, dpy)
                seg['disp'].append(dp); seg['log'].append((mix,miy))


        # 3) mark clicked red
        item.setBrush(SELECT_BRUSH)
        # draw line to clicked
        dpx = lx*GRID_SIZE + GRID_SIZE/2
        dpy = (maxy-ly)*GRID_SIZE + GRID_SIZE/2
        if seg['disp']:
            last_dp = seg['disp'][-1]
            line = self.addLine(last_dp.x(), last_dp.y(), dpx, dpy, LINE_PEN)
            seg['lines'].append(line)
        dp = QPointF(dpx, dpy)
        seg['disp'].append(dp); seg['log'].append((lx,ly))


    def undo(self):
        if not self.segments:
            return
        seg = self.segments[-1]
        if not seg['log']:
            return  # no-op if last segment is empty

        # undo last click
        if seg['log']:
            lx, ly = seg['log'].pop()
            self.slice_items[(lx,ly)].setBrush(NODE_BRUSH)
            seg['disp'].pop()
        if seg['lines']:
            self.removeItem(seg['lines'].pop())
        # undo intermediates
        for _ in range(self.intermediate_count):
            if not seg['log']: break
            lx, ly = seg['log'].pop()
            self.slice_items[(lx,ly)].setBrush(NODE_BRUSH)
            seg['disp'].pop()
            if seg['lines']:
                self.removeItem(seg['lines'].pop())

        # if segment is now empty, remove it
        if not seg['log']:
            self.segments.pop()
            if not self.segments:
                self.new_segment()


    def clear_sketch(self):
        # clear all segments
        for seg in self.segments:
            for ln in seg['lines']:
                self.removeItem(ln)
        self.segments.clear()
        # reset all colors
        for itm in self.slice_items.values():
            itm.setBrush(NODE_BRUSH)
        self.new_segment()


    def load_segments(self, segments_list):
        self.clear_sketch()
        maxy = max(s.y for s in self.dev.slices)
        for point_list in segments_list:
            self.new_segment()
            seg = self.segments[-1]
            for i, (orig_x, orig_y) in enumerate(point_list):
                slice_name = f"SLICE_X{orig_x}Y{orig_y}"
                s = next((s for s in self.dev.slices if s.name == slice_name), None)
                if s is None:
                    print(f"Warning: Slice {orig_x},{orig_y} not found")
                    continue
                lx, ly = s.x, s.y
                item = self.slice_items[(lx, ly)]
                item.setBrush(SELECT_BRUSH)  # Color all as selected for loaded segments
                dpx = lx * GRID_SIZE + GRID_SIZE / 2
                dpy = (maxy - ly) * GRID_SIZE + GRID_SIZE / 2
                dp = QPointF(dpx, dpy)
                if i > 0:
                    last_dp = seg['disp'][-1]
                    line = self.addLine(last_dp.x(), last_dp.y(), dpx, dpy, LINE_PEN)
                    seg['lines'].append(line)
                seg['disp'].append(dp)
                seg['log'].append((lx, ly))



# ── MAIN WINDOW ─────────────────────────────────────────────────────────
class MainWin(QMainWindow):
    def __init__(self, device: Device):
        super().__init__()
        self.setWindowTitle("XC6SLX75 - Draw to Route Utility")


        self.scene = DeviceScene(device)
        self.view  = QGraphicsView(self.scene)
        self.view.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setCentralWidget(self.view)


        tb = QToolBar("Actions"); self.addToolBar(tb)


        for txt, fn in [
            ("Zoom In",    lambda: self.view.scale(1.2,1.2)),
            ("Zoom Out",   lambda: self.view.scale(1/1.2,1/1.2)),
            ("Reset View", self.reset_view),
            ("New Segment",self.scene.new_segment),
            ("Undo",       self.scene.undo),
        ]:
            b = QPushButton(txt); b.clicked.connect(fn)
            tb.addWidget(b)


        # combo = QComboBox()
        # for i in range(6): combo.addItem(str(i))
        # combo.currentIndexChanged.connect(self.scene.set_intermediate_count)
        # tb.addWidget(combo)
        
        combo = QComboBox()
        for i in range(6):
            if i == 0:
                desc = "no intermediate LUTs"
            elif i == 1:
                desc = "1 intermediate LUT"
            else:
                desc = f"{i} intermediate LUTs"
            combo.addItem(desc, i)
        combo.currentIndexChanged.connect(lambda idx: self.scene.set_intermediate_count(combo.itemData(idx)))
        tb.addWidget(combo)
        
        combo_wires = QComboBox()
        for i in range(1,5):
            if i == 1:
                desc = "1 wire"
            else:
                desc = f"{i} parallel wires"
            combo_wires.addItem(desc, i)
        combo_wires.currentIndexChanged.connect(lambda idx: self.scene.set_parallel_wires(combo_wires.itemData(idx)))
        tb.addWidget(combo_wires)


        for txt, fn in [
            ("Generate Verilog", self.emit_verilog),
            ("Load Verilog", self.load_verilog),
            ("Clear sketch",     self.scene.clear_sketch)
        ]:
            b = QPushButton(txt); b.clicked.connect(fn)
            tb.addWidget(b)


        self.reset_view()


    def reset_view(self):
        R = self.scene.itemsBoundingRect()
        self.view.fitInView(R, Qt.AspectRatioMode.KeepAspectRatio)


    def emit_verilog(self):
        # Build LUT6 cells segment by segment
        cell_defs = []
        cell_idx  = 0

        if self.scene.parallel_wires == 1:
             for seg_idx, seg in enumerate(self.scene.segments):
                # start this segment from seg_<seg_idx>_in
                prev_sig = f"seg_{seg_idx}_in"
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig}; ///// SEGMENT {seg_idx} BEGINNING /////
                    assign {prev_sig} = {"antenna_in" if seg_idx==0 else "wire_0"}; /// PUT SEGMENT {seg_idx} INPUT HERE
                """))
                
                for lx, ly in seg['log']:
                    # find the Slice object
                    s_obj = next(s for s in self.scene.dev.slices if s.x == lx and s.y == ly)
                    sig = f"wire_{cell_idx}"


                    cell_defs.append(textwrap.dedent(f"""\
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx} (
                            .O({sig}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig})
                        );
                    """))
                    # Update previous signal for next LUT
                    prev_sig  = sig
                    cell_idx += 1


        elif self.scene.parallel_wires == 2: 
            for seg_idx, seg in enumerate(self.scene.segments):
                # start this segment from seg_<seg_idx>_in
                prev_sig_lut_a = f"seg_{seg_idx}_in_LUT_A"
                prev_sig_lut_b = f"seg_{seg_idx}_in_LUT_B"
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_a}; ///// SEGMENT {seg_idx} BEGINNING /////
                    assign {prev_sig_lut_a} = {"antenna_in" if seg_idx==0 else "wire_0_lut_a"} ; /// PUT SEGMENT {seg_idx} LUT A INPUT HERE
                """))
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_b};
                    assign {prev_sig_lut_b} = {"antenna_in" if seg_idx==0 else "wire_0_lut_b"}; /// PUT SEGMENT {seg_idx} LUT B INPUT HERE
                """))
                
                for lx, ly in seg['log']:
                    # find the Slice object
                    s_obj = next(s for s in self.scene.dev.slices if s.x == lx and s.y == ly)
                    sig_lut_a = f"wire_{cell_idx}_lut_a"
                    sig_lut_b = f"wire_{cell_idx}_lut_b"


                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_a};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="A5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_a (
                            .O({sig_lut_a}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_a})
                        );
                    """))
                    
                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_b};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="B5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_b (
                            .O({sig_lut_b}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_b})
                        );
                    """))


                    prev_sig_lut_a  = sig_lut_a
                    prev_sig_lut_b  = sig_lut_b
                    cell_idx += 1


        elif self.scene.parallel_wires == 3:
            for seg_idx, seg in enumerate(self.scene.segments):
                # start this segment from seg_<seg_idx>_in
                prev_sig_lut_a = f"seg_{seg_idx}_in_LUT_A"
                prev_sig_lut_b = f"seg_{seg_idx}_in_LUT_B"
                prev_sig_lut_c = f"seg_{seg_idx}_in_LUT_C"
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_a}; ///// SEGMENT {seg_idx} BEGINNING /////
                    assign {prev_sig_lut_a} = {"antenna_in" if seg_idx==0 else "wire_0_lut_a"} ; /// PUT SEGMENT {seg_idx} LUT A INPUT HERE
                """))
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_b};
                    assign {prev_sig_lut_b} = {"antenna_in" if seg_idx==0 else "wire_0_lut_b"}; /// PUT SEGMENT {seg_idx} LUT B INPUT HERE
                """))
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_c}; 
                    assign {prev_sig_lut_c} = {"antenna_in" if seg_idx==0 else "wire_0_lut_c"}; /// PUT SEGMENT {seg_idx} LUT C INPUT HERE
                """))
                
                
                for lx, ly in seg['log']:
                    # find the Slice object
                    s_obj = next(s for s in self.scene.dev.slices if s.x == lx and s.y == ly)
                    sig_lut_a = f"wire_{cell_idx}_lut_a"
                    sig_lut_b = f"wire_{cell_idx}_lut_b"
                    sig_lut_c = f"wire_{cell_idx}_lut_c"


                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_a};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="A5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_a (
                            .O({sig_lut_a}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_a})
                        );
                    """))
                    
                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_b};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="B5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_b (
                            .O({sig_lut_b}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_b})
                        );
                    """))
                    
                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_c};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="C5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_c (
                            .O({sig_lut_c}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_c})
                        );
                    """))
                    
                    prev_sig_lut_a  = sig_lut_a
                    prev_sig_lut_b  = sig_lut_b
                    prev_sig_lut_c  = sig_lut_c
                    cell_idx += 1
                    
        else:
            for seg_idx, seg in enumerate(self.scene.segments):
                # start this segment from seg_<seg_idx>_in
                prev_sig_lut_a = f"seg_{seg_idx}_in_LUT_A"
                prev_sig_lut_b = f"seg_{seg_idx}_in_LUT_B"
                prev_sig_lut_c = f"seg_{seg_idx}_in_LUT_C"
                prev_sig_lut_d = f"seg_{seg_idx}_in_LUT_D"
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_a}; ///// SEGMENT {seg_idx} BEGINNING /////
                    assign {prev_sig_lut_a} = {"antenna_in" if seg_idx==0 else "wire_0_lut_a"} ; /// PUT SEGMENT {seg_idx} LUT A INPUT HERE
                """))
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_b};
                    assign {prev_sig_lut_b} = {"antenna_in" if seg_idx==0 else "wire_0_lut_b"}; /// PUT SEGMENT {seg_idx} LUT B INPUT HERE
                """))
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_c}; 
                    assign {prev_sig_lut_c} = {"antenna_in" if seg_idx==0 else "wire_0_lut_c"}; /// PUT SEGMENT {seg_idx} LUT C INPUT HERE
                """))
                
                cell_defs.append(textwrap.dedent(f"""\
                    (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {prev_sig_lut_d}; 
                    assign {prev_sig_lut_d} = {"antenna_in" if seg_idx==0 else "wire_0_lut_d"}; /// PUT SEGMENT {seg_idx} LUT D INPUT HERE
                """))
                
                
                for lx, ly in seg['log']:
                    # find the Slice object
                    s_obj = next(s for s in self.scene.dev.slices if s.x == lx and s.y == ly)
                    sig_lut_a = f"wire_{cell_idx}_lut_a"
                    sig_lut_b = f"wire_{cell_idx}_lut_b"
                    sig_lut_c = f"wire_{cell_idx}_lut_c"
                    sig_lut_d = f"wire_{cell_idx}_lut_d"


                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_a};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="A5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_a (
                            .O({sig_lut_a}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_a})
                        );
                    """))
                    
                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_b};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="B5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_b (
                            .O({sig_lut_b}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_b})
                        );
                    """))
                    
                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_c};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="C5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_c (
                            .O({sig_lut_c}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_c})
                        );
                    """))
                    
                    cell_defs.append(textwrap.dedent(f"""
                        (* S = "TRUE"*) (* dont_touch = "TRUE" *) wire {sig_lut_d};
                        (* S="TRUE", dont_touch="TRUE", LOC="{s_obj.name}", BEL="D5LUT" *)
                        LUT6 #(.INIT(64'hFFFFFFFF00000000)) lut_{cell_idx}_d (
                            .O({sig_lut_d}),
                            .I0(1'b0), .I1(1'b0), .I2(1'b0),
                            .I3(1'b0), .I4(1'b0), .I5({prev_sig_lut_d})
                        );
                    """))

                    prev_sig_lut_a  = sig_lut_a
                    prev_sig_lut_b  = sig_lut_b
                    prev_sig_lut_c  = sig_lut_c
                    prev_sig_lut_d  = sig_lut_d
                    cell_idx += 1
        
        out, _ = QFileDialog.getSaveFileName(
            self, "Save Verilog", "sketch_route.v", "Verilog (*.v)"
        )
        if out:
            module_name = pathlib.Path(out).stem
            # Wrap in module boilerplate
            verilog = textwrap.dedent(f"""\
// Auto-generated by fpga_route_gui.py
// Total LUTs: {cell_idx} across {len(self.scene.segments)} segments

module {module_name} (
    input antenna_in
    );
    // hand-drawn segments
        {chr(10).join(cell_defs)}
    
    endmodule
            """)
            pathlib.Path(out).write_text(verilog)
            QMessageBox.information(self, "Done", f"Saved to {out}")


    def load_verilog(self):
        fn, _ = QFileDialog.getOpenFileName(
            self, "Load Verilog", "", "Verilog (*.v)"
        )
        if not fn:
            return
        with open(fn, 'r') as f:
            text = f.read()
        # Parse the Verilog text
        segments = []
        lines = text.splitlines()
        current_seg = None
        for line in lines:
            if 'SEGMENT' in line and 'BEGINNING' in line:
                # m = re.search(r'seg_(\d+)_in;.*?SEGMENT (\d+) BEGINNING', line)
                m = re.search(r'seg_(\d+)_in(?:_LUT_[A-D])?;.*?SEGMENT (\d+) BEGINNING', line)
                if m:
                    seg_id = int(m.group(1))
                    current_seg = []
                    segments.append(current_seg)
                    continue
            if current_seg is not None and 'LOC="' in line:
                m = re.search(r'LOC="SLICE_X(\d+)Y(\d+)"', line)
                if m:
                    x = int(m.group(1))
                    y = int(m.group(2))
                    #current_seg.append((x, y))
                    # Add only if different from the last added (to handle duplicates from parallel wires)
                    if not current_seg or (x, y) != current_seg[-1]:
                        current_seg.append((x, y))
        # Load into scene
        self.scene.load_segments(segments)
        self.reset_view()
        QMessageBox.information(self, "Loaded", f"Loaded from {fn}")



# ── ENTRY ────────────────────────────────────────────────────────────────
def main():
    dev = Device(XDLRC_PATH)
    app = QApplication(sys.argv)
    w = MainWin(dev);  w.resize(900,1200);  w.show()
    sys.exit(app.exec())


if __name__=="__main__":
    main()
