# TM1638 LED&KEY Module Configured for Displaying NIM Number with a behavioral input
Delapan digit 7-segment, delapan LED, dan tombol. Sinyal `clk` berasal dari clock FPGA; `tm_cs`, `tm_clk`, dan `tm_dio` terhubung ke modul TM1638.

# how the code works
1. **Mengirim data ke TM1638.** Modul `tm1638` menangani komunikasi serial. Sinyal `tm_rw` menentukan arah jalur data dua arah `tm_dio`: FPGA mengirim saat menulis (`tm_rw=1`) dan melepas jalur agar TM1638 bisa mengirim data tombol saat membaca. `tm_latch` memberi tahu modul komunikasi kapan sebuah byte siap diproses, sedangkan `busy` menandakan komunikasi sedang berlangsung.
2. **Menggerakkan teks dan LED.** Array `msg[0:24]` menyimpan pola segmen untuk NIM, tiga karakter kosong sebagai pemisah, lalu beberapa karakter awal yang diulang untuk menyambungkan animasi. `offset` menentukan karakter pertama yang tampil pada delapan digit. Setiap kali `timer` mencapai 12.000.000 hitungan clock, teks bergeser satu posisi. Mode dipilih dari tombol:
   - `keys[7]` (S1): geser ke satu arah.
   - `keys[6]` (S2): geser ke arah sebaliknya.
   - `keys[5]` (S3): mode ping-pong.

   LED berjalan bolak-balik mengikuti `led_pos`; `led_timer` mengatur kecepatannya. Pada langkah penulisan tampilan, tiap pola karakter dikirim bergantian dengan bit LED yang bersesuaian.
3. **Membaca tombol dan memperbarui tampilan.** State machine `step` menjalankan urutan komunikasi: membaca tombol, mengirim perintah tulis, mengirim pasangan data digit dan LED, lalu mengirim perintah tampilan. `counter[0]` membatasi eksekusi state machine agar tidak berjalan pada setiap siklus clock.

Nilai timer adalah **jumlah siklus clock**, bukan waktu tetap. Misalnya, pada clock 12 MHz, 12.000.000 hitungan setara kira-kira satu detik.

# oss-cad-suite-tcl-template by ABJ
A template project to synthesys, place & route and generate bitstream.
The environment is set for running on Windows and ICESugar FPGA board.

# pre-requisites
Edit file setenv.bat following your local drive

# how to run
1. Setup environment for OSS CAD Suite <br />
**$ setenv.bat**

2. Create project, synthesis, place & route and generate bitsteram <br />
	option 1: <br />
	**$ make syn** <br />
	**$ make pnr** <br />
  **$ make bit** <br />
	
	option 2: <br />
	**$ make all** <br />

3. Load bitstream to FPGA board <br />
**$ make flash**

4. Clean build directory including project files <br />
**$ make clean**

5. To run simulation <br />

	option 1: <br />
	**$ make compile** <br />
	**$ make vvp** <br />
  **$ make gtk** <br />
	
	option 2: <br />
	**$ make sim** <br />

