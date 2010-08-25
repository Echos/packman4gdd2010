# -*- coding: utf-8 -*-
$VERBOSE=true if $DEBUG

require 'curses'
include Curses

p_map1 =<<EOF
50
11 7
###########
#.V..#..H.#
#.##...##.#
#L#..#..R.#
#.#.###.#.#
#....@....#
###########
EOF

p_map2 =<<EOF
300
20 17
####################
###.....L..........#
###.##.##.##L##.##.#
###.##.##.##.##.##.#
#.L................#
#.##.##.##.##.##.###
#.##.##L##.##.##.###
#.................L#
#.#.#.#J####J#.#.#.#
#L.................#
###.##.##.##.##.##.#
###.##.##R##.##.##.#
#................R.#
#.##.##.##.##R##.###
#.##.##.##.##.##.###
#\@....R..........###
####################
EOF

p_map3 =<<EOF
700
58 17
##########################################################
#........................................................#
#.###.#########.###############.########.###.#####.#####.#
#.###.#########.###############.########.###.#####.#####.#
#.....#########....J.............J.......###.............#
#####.###.......#######.#######.########.###.#######.#####
#####.###.#####J#######.#######.########.###.##   ##.#####
#####.###L#####.##   ##L##   ##.##    ##.###.##   ##.#####
#####.###..H###.##   ##.##   ##.########.###.#######J#####
#####.#########.##   ##L##   ##.########.###.###V....#####
#####.#########.#######.#######..........###.#######.#####
#####.#########.#######.#######.########.###.#######.#####
#.....................L.........########..........R......#
#L####.##########.##.##########....##....#########.#####.#
#.####.##########.##.##########.##.##.##.#########.#####.#
#.................##............##..@.##...............R.#
##########################################################
EOF

p_map = p_map3

@@t = -1

@@me = nil
@@en = Array.new 

(
@@w = Curses::Window.new(200, 200, 0, 0)
)if $VERBOSE

@@symbol_en ={
  'V' => :enm_V,
  'H' => :enm_H,
  'L' => :enm_L,
  'R' => :enm_R,
  'J' => :enm_J,
}

@@symbol = {
  '@' => :player,
  '#' => :wall,
  ' ' => :space,
  '.' => :dot,
}

@@history1 =  nil
@@symbol.merge!(@@symbol_en)

@@symbol.each do |k,v|
  @@symbol[v]=k
end

@@dot_poss = Array.new

#計測MAX
@@count_max = p_map.to_a[0].strip.to_i

#サイズを計測
@@width  = p_map.to_a[1].strip.split(/\s/)[0].strip.to_i
@@height = p_map.to_a[1].strip.split(/\s/)[1].strip.to_i

p_map = p_map.to_a[2..-1].to_s

#初期ポイント
@@points = Array.new( @@height ).map!{ Array.new( @@width ).map!{Array.new(3,0)} }

#交差点リスト
@@cross_point_list = Array.new
#ストリートリスト
@@street_list = Array.new

def copy(ary)
  return Marshal.load(Marshal.dump(ary))
end

class Pos
  attr_accessor :y
  attr_accessor :x
  attr_accessor :symbol
  def initialize(y,x,mark)
    @x = x
    @y = y
    @symbol = mark
  end
  def ==(other_vec)
    other_vec.x == @x && other_vec.y == @y
  end

  #相対距離を取得
  def +(other_vec)
    return (other_vec.x - @x).abs + (other_vec.y - @y).abs
  end
  

end

class Animal
  attr_accessor :pos_pas
  attr_accessor :pos_cur
  attr_accessor :type
  @j_count = 0
  i = 0
  %w(UP LEFT DOWN RIGHT).each do |name|
    const_set(name, i)
    i += 1
  end
  
  
  def initialize(pos,type)
    @pos_pas = pos
    @pos_cur = pos
    @type = type
    @j_count = 0
  end

  def move(pos)
    @pos_pas = copy(@pos_cur)
    @pos_cur = copy(pos)
  end
  
  def auto_move()
    if @@t==0
      move_to_any
    else
      st_list = street_type()
      if st_list.length == 1
        move(st_list[0])
      elsif st_list.length == 2
        st_list.each do |pos|
          (move(pos);break) if !(pos == pos_pas)
        end
      else
        #相対位置
        dy = potition_from_me_y
        dx = potition_from_me_x
        case @type
        when :enm_V
          if dy != 0 && @@points[@pos_cur.y+dy][@pos_cur.x][0].is_move?
            move(Pos.new(pos_cur.y + dy, pos_cur.x,""))
          elsif dx != 0 && @@points[@pos_cur.y][@pos_cur.x+dx][0].is_move?
            move(Pos.new(pos_cur.y ,pos_cur.x + dx,""))
          else
            (move_to_any;return) 
          end
        when :enm_H
          if dx != 0 && @@points[@pos_cur.y][@pos_cur.x+dx][0].is_move?
            move(Pos.new(pos_cur.y ,pos_cur.x + dx,""))
          elsif dy != 0 && @@points[@pos_cur.y+dy][@pos_cur.x][0].is_move?
            move(Pos.new(pos_cur.y + dy, pos_cur.x,""))
          else
            (move_to_any;return) 
          end
        when :enm_L
          point = get_vector + 3
          while !move_to_vector(point)
            point -= 1
          end
        when :enm_R
          point = get_vector + 1
          while !move_to_vector(point)
            point += 1
          end
        when :enm_J
          @j_count = (@j_count + 1) % 2
          if @j_count.odd?
            point = get_vector + 3
            while !move_to_vector(point)
              point -= 1
            end
          else
            point = get_vector + 1
            while !move_to_vector(point)
              point += 1
            end
          end
        end
      end
    end
  end
  private
  def potition_from_me_y
    y = @@me.pos_cur.y - @pos_cur.y
    if y > 0
      return 1
    elsif y < 0
      return -1
    else
      return 0
    end
  end

  def potition_from_me_x
    x = @@me.pos_cur.x - @pos_cur.x
    if x > 0
      return 1
    elsif x < 0
      return -1
    else
      return 0
    end
  end

  def move_to_any
    #下、左、上、右
    if(@@points[@pos_cur.y+1][@pos_cur.x][0].is_move?)
      move(Pos.new(pos_cur.y+1,pos_cur.x,""))
    elsif(@@points[@pos_cur.y][@pos_cur.x-1][0].is_move?)
      move(Pos.new(pos_cur.y,pos_cur.x-1,""))
    elsif(@@points[@pos_cur.y-1][@pos_cur.x][0].is_move?)
      move(Pos.new(pos_cur.y-1,pos_cur.x,""))
    elsif(@@points[@pos_cur.y][@pos_cur.x+1][0].is_move?)
      move(Pos.new(pos_cur.y,pos_cur.x+1,""))
    end
  end

  def move_to_vector(vector)
    case (vector % 4)
    when DOWN
      if(@@points[@pos_cur.y+1][@pos_cur.x][0].is_move?)
        move(Pos.new(pos_cur.y+1,pos_cur.x,""))
        return true
      else
        return false
      end
    when LEFT
      if(@@points[@pos_cur.y][@pos_cur.x-1][0].is_move?)
        move(Pos.new(pos_cur.y,pos_cur.x-1,""))
        return true
      else
        return false
      end
    when UP
      if(@@points[@pos_cur.y-1][@pos_cur.x][0].is_move?)
        move(Pos.new(pos_cur.y-1,pos_cur.x,""))
        return true
      else
        return false
      end
    when RIGHT
      if(@@points[@pos_cur.y][@pos_cur.x+1][0].is_move?)
        move(Pos.new(pos_cur.y,pos_cur.x+1,""))
        return true
      else
        return false
      end
    end
  end
  
  # 進入方向
  def get_vector
    y = @pos_cur.y - @pos_pas.y
    x = @pos_cur.x - @pos_pas.x
    return UP if y > 0
    return DOWN if y < 0
    return LEFT if x > 0
    return RIGHT if x < 0
  end

  public
  def street_type
    return point_type(Pos.new(@pos_cur.y,@pos_cur.x,"Z"))
  end
end

def point_type(pos)
    list = Array.new
  begin
    list << Pos.new(pos.y-1,pos.x,"k") if @@points[pos.y - 1][pos.x][0].is_move?
    list << Pos.new(pos.y,pos.x-1,"h") if @@points[pos.y][pos.x - 1][0].is_move?
    list << Pos.new(pos.y+1,pos.x,"j") if @@points[pos.y + 1][pos.x][0].is_move?
    list << Pos.new(pos.y,pos.x+1,"l") if @@points[pos.y][pos.x + 1][0].is_move?
    return list
  rescue
    return list
  end
end

class Human < Animal
  def move(pos)
    super
    p = Pos.new(pos.y,pos.x,".")
    @@dot_poss.delete(p) if @@points[pos.y][pos.x][0].type == :dot
#    @@next_dot = select_near_dot if @@points[pos.y][pos.x][0].type == :dot
    nd = select_near_dot
    @@next_dot = Pos.new(nd.y,nd.x,@@t) if (@@next_dot == p || @@t - @@next_dot.symbol > @@count_max / 5 ) && !nd.nil?


    @@next_dot = select_near_dot if @@next_dot == p
    @@points[pos.y][pos.x][0].type = :space

  end

  #自操作用
  def move_mine(c)
    (move(Pos.new(@pos_cur.y-1,@pos_cur.x,"k"));return true) if c == 'k' && @@points[@pos_cur.y-1][@pos_cur.x][0].is_move?
    (move(Pos.new(@pos_cur.y,@pos_cur.x-1,"h"));return true) if c == 'h' && @@points[@pos_cur.y][@pos_cur.x-1][0].is_move?
    (move(Pos.new(@pos_cur.y+1,@pos_cur.x,"j"));return true) if c == 'j' && @@points[@pos_cur.y+1][@pos_cur.x][0].is_move?
    (move(Pos.new(@pos_cur.y,@pos_cur.x+1,"l"));return true) if c == 'l' && @@points[@pos_cur.y][@pos_cur.x+1][0].is_move?
    (move(Pos.new(@pos_cur.y,@pos_cur.x,"."));return true) if c == '.'
    return false
  end

 #  def street_type
 #    list = super
 # #    #待機を追加
 # #   list << Pos.new(@pos_cur.y,@pos_cur.x,".")
 #    return list
 #  end
end

class Chip
  attr_accessor :x
  attr_accessor :y
  attr_accessor :type
  
  def initialize(y,x,type)
    @x = x
    @y = y
    if type == @@symbol[:wall] || type == @@symbol[:dot]  || type == @@symbol[:space]
      @type = @@symbol[type]
    else
      @type = :space
    end
  end
  def is_move?
    return @type != :wall
  end
  def pos
    return Pos.new(@y,@x,"@")
  end
end

def print_map()
  (
  @@w.setpos(1,0)
  )if $VERBOSE
  paint = Array.new
  @@points.each do |points_y|
    line = ""
    points_y.each do |points_x|
      line << @@symbol[points_x[0].type]
    end
    paint << line
  end
  paint[@@me.pos_cur.y][@@me.pos_cur.x..@@me.pos_cur.x] = @@symbol[@@me.type]
  @@en.each do |en|
      paint[en.pos_cur.y][en.pos_cur.x..en.pos_cur.x] = @@symbol[en.type]
  end
  (
  paint.each do |line|
    @@w.addstr(line +"\n")
  end
  @@w.addstr( "Dot Left #{dot_num()}\n")
  @@w.addstr( "Max Dist #{max_distance()}\n")
  @@w.refresh
   )if $VERBOSE
end

def dot_num
  return @@dot_poss.length
end

def isGoal?
  return dot_num == 0
end

def isDead?
  ret = false
  @@en.each do |en|
    if @@me.pos_cur == en.pos_cur || (@@me.pos_cur == en.pos_pas && @@me.pos_pas == en.pos_cur)
      ret = true
    end
    return true if ret
  end
  return false
end

class History
  attr_accessor :count
  attr_accessor :points
  attr_accessor :dot_poss
  attr_accessor :next_dot
  attr_accessor :en
  attr_accessor :me
  attr_accessor :selected_move_point
  attr_accessor :move_point_list
  attr_accessor :waitpoint
  def initialize(count,points,dot_poss,next_dot,move_point_list,me,en)
    @count = count
    @points = copy(points)
    @dot_poss = copy(dot_poss)
    @next_dot = next_dot
    @move_point_list = copy(move_point_list)
    @me = copy(me)
    @en = copy(en)
    @waitpoint = nil
  end

  def is_next?
    alg_1
    return !@selected_move_point.nil?
  end

  #次のます決定アルゴリズム１
  def alg_1
    dot_list = Array.new
    #近くのDotを率先する
    @move_point_list.each do |mp|
      if @@points[mp.y][mp.x][0].type == :dot
        dot_list << mp
      end
    end
    if dot_list.length > 0 
      @selected_move_point = @move_point_list.delete(dot_list[rand(dot_list.length)])
    else
      @selected_move_point = @move_point_list.delete_at(rand(@move_point_list.length))
    end
    return @selected_move_point
  end


  #次のます決定アルゴリズム２
  def alg_2
    #実行待ちポイントがあったら、ソレを優先する。
    if !waitpoint.nil?
      return waitpoint
    end
    #目標に近づくようがんばる
    x = 1  if  (@@next_dot.x - @@me.pos_cur.x) > 0
    x = 0  if  (@@next_dot.x - @@me.pos_cur.x) == 0
    x = -1 if  (@@next_dot.x - @@me.pos_cur.x) < 0
    y = 1  if  (@@next_dot.y - @@me.pos_cur.y) > 0
    y = 0  if  (@@next_dot.y - @@me.pos_cur.y) == 0
    y = -1 if  (@@next_dot.y - @@me.pos_cur.y) < 0
    
    possible_pos = Array.new
    px = Pos.new(@@me.pos_cur.y , @@me.pos_cur.x + x,"X")
    py = Pos.new(@@me.pos_cur.y + y , @@me.pos_cur.x,"Y")

    possible_pos << px if @move_point_list.include? px
    possible_pos << py if @move_point_list.include? py

    if possible_pos.length > 0
      tmp = possible_pos[rand(possible_pos.length)]
      @move_point_list.each do |mp|
        if mp == tmp
          @selected_move_point = mp 
          @move_point_list.delete(tmp)
        end
      end
    else
      @selected_move_point = @move_point_list.delete_at(rand(@move_point_list.length))
    end

    #選択された場所が、交差点か？
    if !@selected_move_point.nil? && point_type(@selected_move_point).length > 2 
      #交差点であるばあい、次のフェーズを予想。
      #もし次のフェーズで敵がそこにいれば待機する。
      tmpen = copy(@@en)
      wait = false
      tmpen.each do |en|
        en.auto_move
        (wait = true ; break) if @selected_move_point + en.pos_cur == 0
      end
    end
    if (wait)
      #次回予約ポイントに入れる
      @waitpoint = copy(@selected_move_point)
      #待機する
      @selected_move_point = Pos.new(@@me.pos_cur.y,@@me.pos_cur.x,".")
    end

    return @selected_move_point
  end

end

def fase_next(mp)
  #敵移動
  @@en.each do |en|
    en.auto_move
  end
  #自機移動
  @@me.move(mp) if !$DEBUG
  (
   c=@@w.getch
   while(@@me.move_mine(c.chr)==false)
     c=@@w.getch
   end
   ) if $DEBUG

  return !isDead?
end

def print_screen(historyList)
  (

   @@w.setpos(0,0)
   @@w.addstr("Count : #{@@t}")
   @@w.setpos(22,0)
   @@w.addstr(root(historyList))
   @@w.refresh
   i = -1
   @@goal_list.each do |g|
     i+=1
     @@w.setpos(i + 10,30)
     @@w.addstr(g)
   end
#   @@w.addstr(root(historyList))
   print_map
   )if $VERBOSE
end
  

@@goal_list = Array.new
historyList = Array.new

def root(historyList)
  ret = ""
  historyList.each do |hist|
    ret += hist.selected_move_point.symbol.to_s
  end
  p ret if !$VERBOSE

  return ret
end

def make_dot_poss
  @@height.times do |h|
    @@width.times do |w|
      @@dot_poss << Pos.new(h,w,".") if @@points[h][w][0].type == :dot
    end
  end
end

#自機から一番近いDotを選定
def select_near_dot
  near_list = nil
  dist=100000
  return nil if @@dot_poss.length ==0
  @@dot_poss.each do |d|
    td = @@me.pos_cur + d
    if td < dist
      near_list = Array.new
      near_list << d
      dist = td
    elsif td = dist
      near_list << d
    end
  end
  return near_list[rand(near_list.length)]
end

#予想しえる、最小歩数を算出する。
#四隅の距離、間のdot数、自分からの距離で算出
def max_distance
  distance_list = Array.new
  #左上
  ul = 100000
  #右上
  ur = 0
  #左下
  dl = 0
  #右下
  dr = 0
  
  posul = nil
  posur = nil
  posdl = nil
  posdr = nil
  
  if @@dot_poss.length > 3
    @@dot_poss.each do |pos|
      tul = pos.x + pos.y
      tur = pos.x + (@@height - pos.y)
      tdl = (@@width - pos.x) + pos.y
      tdr = pos.x + pos.y
      (posul = copy(pos) ; ul = tul) if ul > tul
      (posur = copy(pos) ; ur = tur) if ur < tur
      (posdl = copy(pos) ; dl = tdl) if dl < tdl
      (posdr = copy(pos) ; dr = tdr) if dr < tdr
    end
    distance_list << @@me.pos_cur + posul
    distance_list << @@me.pos_cur + posur
    distance_list << @@me.pos_cur + posdl
    distance_list << @@me.pos_cur + posdr
    
    xs = Array.new
    ys = Array.new

    ys << posul.y
    xs << posul.x

    ys << posur.y
    xs << posur.x

    ys << posdl.y
    xs << posdl.x

    ys << posdr.y
    xs << posdr.x
    
    cent_count = 0;
    @@dot_poss.each do |pos|
      cent_count += 1 if pos.x > xs.min && pos.x < xs.max && pos.y > ys.min && pos.y < ys.max
    end
    dtmp = Array.new
    dtmp << (posul + posur)
    dtmp << (posur + posdr)
    dtmp << (posdr + posdl)
    dtmp << (posdl + posul)
    dtmp.sort!.delete_at(-1)

    return dtmp[0] + dtmp[1] + dtmp[2] + distance_list.min
  end
  case @@dot_poss.length
  when 3
    distance_list << @@me.pos_cur + @@dot_poss[0]
    distance_list << @@me.pos_cur + @@dot_poss[1]
    distance_list << @@me.pos_cur + @@dot_poss[2]
    dtmp = Array.new
    dtmp << @@dot_poss[0] + @@dot_poss[1]
    dtmp << @@dot_poss[1] + @@dot_poss[2]
    dtmp << @@dot_poss[2] + @@dot_poss[0]
    dtmp.sort!.delete_at(-1)
    return dtmp[0] + dtmp[1] + distance_list.min
  when 2
    distance_list << @@me.pos_cur + @@dot_poss[0]
    distance_list << @@me.pos_cur + @@dot_poss[1]

    return (@@dot_poss[0] + @@dot_poss[1]) + distance_list.min
  when 1
    return (@@dot_poss[0] + @@me.pos_cur)
  else
    return 0
  end
end

@waitpoint = nil
def do_packman(th,historyList)
  while (true)
    h = copy(historyList.pop)
    
    return if h == nil
    
    #移動先が無ければ履歴を戻る
    next if !(h.is_next?)
    h.selected_move_point = @@me.pos_cur if $DEBUG
    @@points = copy(h.points)
    @@dot_poss = copy(h.dot_poss)
    @@next_dot = h.next_dot
    @@en = copy(h.en)
    @@me = copy(h.me)
    @@t = h.count
    @@t += 1 

    #次回予約移動先が有れば、保存しておき、次回の履歴に利用する。
    @waitpint = h.waitpoint
    h.waitpoint = nil

    #既存分を再保存
    historyList << copy(h)

    #描画
    (
     @@w.setpos(0,15)
     @@w.addstr(th.to_s)
     @@w.refresh
     ) if $VERBOSE
    print_screen(historyList)

    #移動開始
    if fase_next(h.selected_move_point)

      #残りDotで 残り歩数の見切りとする
      if dot_num  > th - @@t
        return if (nil == historyList.delete_at(-1))
        next
      end

      #最遠Dotとの距離で 残り歩数の見切りとする
      if max_distance  > th - @@t
        return if (nil == historyList.delete_at(-1))
        next
      end

      #新規履歴保存
      #ゴールしていたら以降調査しない
      if isGoal?
        rootmap = root(historyList)

        #次回は１手順少ないものを探索
        th = rootmap.length - 1

        @@goal_list << rootmap
        p "#{rootmap} :#{rootmap.length}" if !$VERBOSE
        hl = Array.new
        hl << copy(@@history1)

        #最初期目標を復元
        @@next_dot = @@history1.next_dot
        do_packman(th,hl)
        return
      end

      #指定数オーバーで保存しない
      if @@t < th
        h = History.new(@@t,@@points,@@dot_poss,@@next_dot,@@me.street_type,@@me,@@en)
        h.waitpoint = @waitpoint
        h.selected_move_point = copy(@@me.pos_cur) 
        historyList << h

#        @@w.getch
      end
    end
  end
end

#読み込み
py = -1
map = Array.new
p_map.each do |line|
  px = -1
  py += 1
  line.strip.each_byte do |c|
    px += 1
    @@points[py][px][0] = Chip.new(py,px,c.chr)
    if c.chr == @@symbol[:player]
      @@me = Human.new(Pos.new(py,px,""),:player)
    end
    if @@symbol_en.key?(c.chr)
      @@en << Animal.new(Pos.new(py,px,""),@@symbol_en[c.chr])
    end
  end
end
#通路属性を付与
@@points.each do |points_y|
  points_y.each do |points_x|
    if @@points[points_x[0].pos.y][points_x[0].pos.x][0].type == :wall
      @@points[points_x[0].pos.y][points_x[0].pos.x][1] = 0
    else
      @@points[points_x[0].pos.y][points_x[0].pos.x][1]= point_type(points_x[0].pos).length
      if @@points[points_x[0].pos.y][points_x[0].pos.x][1] >= 3
        @@cross_point_list << @@points[points_x[0].pos.y][points_x[0].pos.x][0].pos
      end
    end
  end
end
#ストリートリストを作成
#ストリート配列→スタート ストリート 出口マップ 


#直近の目標座標
#手動で指定すれば最初期の目標となる

@@next_dot = Pos.new(9,49,800)

#初期状態を作成
make_dot_poss

#目標設定
nd = select_near_dot
@@next_dot = Pos.new(nd.y,nd.x,@@t) if @@next_dot.nil?

h = History.new(@@t,@@points,@@dot_poss,@@next_dot,@@me.street_type,@@me,@@en)
@@history1 = copy(h)
historyList << h

do_packman(@@count_max,historyList)

(
@@w.clear
@@w.refresh
Curses.close_screen
)if $VERBOSE

min_root = 100000
@@goal_list.each do |t_root|
  min_root = t_root.length if t_root.length < min_root
end

@@goal_list.each do |t_root|
  if t_root.length == min_root
    p t_root
  end
end
@@goal_list.each do |t_root|
  p "#{t_root} : #{t_root.length}"
end
