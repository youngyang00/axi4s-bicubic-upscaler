package imageProcessPkg;

function automatic real abs_real(input real x);
  return (x < 0) ? -x : x;
endfunction : abs_real

  // value1, value2의 상대 오차가 threshold 미만이면 0, 이상이면 1 반환
function automatic int valueCompare(
  input real value1,
  input real value2,
  input real threshold,
  input real maxValue
);
 real difference;
 // 사용자 정의 abs_real 함수를 사용
 difference = abs_real((value1 - value2) / maxValue);
 $display("Percentage error: %0f%%", difference * 100);
 if (difference < threshold)
   return 0;
 else
   return 1;
endfunction : valueCompare

function automatic void readPixelTxt_RGB(
  string          filename,
  ref int         frame_r[][],
  ref int         frame_g[][],
  ref int         frame_b[][]
);
  int    fd;
  string line;
  int code;
  int    x, y;
  int    r_val, g_val, b_val;

  fd = $fopen(filename, "r");
  if (fd == 0) begin
     $display("ERROR: Cannot open file %s", filename);
     $finish;
  end

  if (!$fgets(line, fd)) begin
     $display("ERROR: Empty file %s", filename);
     $finish;
  end

  while (!$feof(fd)) begin
     if (!$fgets(line, fd)) break;
     // 주석(#) 또는 빈 줄 skip
     if (line.len() == 0 || line.substr(0,1) == "#") continue;
     // 행 파싱
     code = $sscanf(line, "%d %d %h %h %h", x, y, r_val, g_val, b_val);
     if (code != 5) begin
        $display("ERROR: Malformed line: %s", line);
        $finish;
     end
     frame_r[x][y] = r_val;
     frame_g[x][y] = g_val;
     frame_b[x][y] = b_val;
  end

  $fclose(fd);
endfunction


endpackage : imageProcessPkg
