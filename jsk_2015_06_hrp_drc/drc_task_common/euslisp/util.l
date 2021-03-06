;; utility function
(ros::roseus-add-msgs "std_msgs")
(ros::roseus-add-msgs "smach_msgs")
(ros::roseus-add-srvs "jsk_topic_tools")

(defun ros-rgba (r g b a)
  (let ((color (instance std_msgs::ColorRGBA :init)))
    (send color :r (/ r 255.0))
    (send color :g (/ g 255.0))
    (send color :b (/ b 255.0))
    (send color :a a)
    color))

(setq *success-color* (ros-rgba 91 255 255 1.0))
(setq *warn-color* (ros-rgba 255 202 0 1.0))
(setq *fatal-color* (ros-rgba 230 10 10 1.0))
(setq *select-color* (ros-rgba 150 230 100 1.0))
(setq *wait-color* (ros-rgba 200 230 50 1.0))
(setq *recognize-color* (ros-rgba 50 250 100 1.0))
(setq *execute-color* (ros-rgba 230 0 230 1.0))
(setq *unknown-color* (ros-rgba 251 221 221 1.0))
(setq *transparent-color* (ros-rgba 0 0 0 0))
(setq *execute-color* (ros-rgba 91 255 255 1.0))

(defun xy-distance2 (coords)
  (+ (* (elt (send coords :worldpos) 0)
        (elt (send coords :worldpos) 0))
     (* (elt (send coords :worldpos) 1)
        (elt (send coords :worldpos) 1))))

(defun call-empty-service (srv)
  (let ((req (instance std_srvs::EmptyRequest :init)))
    (ros::service-call srv req)))
(defun call-request-duration (srv time)
  (let ((req (instance jsk_topic_tools::PassthroughDurationRequest :init)))
    (send req :duration (ros::time time))
    (ros::service-call srv req)))

;; topic <---> compressed message conversion
(defun angle-vector-to-float-vector (av time length)
  (let ((ret (instantiate float-vector length)))
    (dotimes (i (length av))
      (setf (elt ret i) (elt av i)))
    (setf (elt ret (length av)) time)
    ret)
  )

(defun float-vector-to-angle-vector (fv)
  (let ((av (subseq fv 0 (length (send *robot* :joint-list))))
        (time (elt fv (length (send *robot* :joint-list)))))
    (list av time)))

(defun position-to-float-vector (pos length)
  ;; 6 parameters are filled
  (let ((ret (instantiate float-vector length)))
    (setf (elt ret 0) (elt pos 0))
    (setf (elt ret 1) (elt pos 1))
    (setf (elt ret 2) (elt pos 2))
    ret))

(defun float-vector-to-position (fv)
  (cond ((>= (length fv) 3)
         (subseq fv 0 3))
        (t
         nil)))

(defun fill-coords-float-vector (coords fv start)
  (setf (elt fv (+ start 0)) (elt (send coords :worldpos) 0))
  (setf (elt fv (+ start 1)) (elt (send coords :worldpos) 1))
  (setf (elt fv (+ start 2)) (elt (send coords :worldpos) 2))
  (setf (elt fv (+ start 3)) (elt (car (send coords :rpy-angle)) 0))
  (setf (elt fv (+ start 4)) (elt (car (send coords :rpy-angle)) 1))
  (setf (elt fv (+ start 5)) (elt (car (send coords :rpy-angle)) 2))
  )

(defun coords-to-float-vector (coords length)
  ;; 6 parameters are filled
  (let ((ret (instantiate float-vector length)))
    (fill-coords-float-vector coords ret 0)
    ret))

(defun float-vector-to-coords (fv)
  (cond ((>= (length fv) 6)
         (make-coords :pos (subseq fv 0 3)
                      :rpy (subseq fv 3 6)))
        (t
         nil))
  )

(defun pos-to-float-vector (pos length)
  (let ((ret (instantiate float-vector length)))
    (setf (elt ret 0) (elt pos 0))
    (setf (elt ret 1) (elt pos 1))
    (setf (elt ret 2) (elt pos 2))
    ret))

(defun rect-polygon-stamped-to-integer-vector (msg length)
  (let ((point-a (list (send (elt (send msg :polygon :points) 0) :x)
                       (send (elt (send msg :polygon :points) 0) :y)))
        (point-b (list (send (elt (send msg :polygon :points) 1) :x)
                       (send (elt (send msg :polygon :points) 1) :y))))
    (coerce (append (list (floor (elt point-a 0))
                          (floor (elt point-a 1))
                          (floor (elt point-b 0))
                          (floor (elt point-b 1)))
                    (make-list (- length 4) :initial-element 0))
            integer-vector)))

(defun polygon-stamped-to-integer-vector (msg length)
  (let ((points
         (mapcar #'(lambda (p)
                     (list (send p :x) (send p :y)))
                 (send msg :polygon :points))))
    (if (> (* 2 (length points)) length)
        (progn
          (ros::ros-warn "Maximum number of points supported is ~A"
                         (/ length 2))
          nil)
      (let ((ret (instantiate integer-vector length)))
        (let ((flat-points (apply #'append points)))
          (dotimes (i (length flat-points))
            (setf (elt ret i) (elt flat-points i))))
        ret))))

(defun double-rect-polygon-stamped-to-integer-vector (msg0 msg1 length)
  (let ((point-a (list (send (elt (send msg0 :polygon :points) 0) :x)
                       (send (elt (send msg0 :polygon :points) 0) :y)))
        (point-b (list (send (elt (send msg0 :polygon :points) 1) :x)
                       (send (elt (send msg0 :polygon :points) 1) :y)))
        (point-c (list (send (elt (send msg1 :polygon :points) 0) :x)
                       (send (elt (send msg1 :polygon :points) 0) :y)))
        (point-d (list (send (elt (send msg1 :polygon :points) 1) :x)
                       (send (elt (send msg1 :polygon :points) 1) :y))))
    (coerce (append (list (floor (elt point-a 0))
                          (floor (elt point-a 1))
                          (floor (elt point-b 0))
                          (floor (elt point-b 1))
                          (floor (elt point-c 0))
                          (floor (elt point-c 1))
                          (floor (elt point-d 0))
                          (floor (elt point-d 1)))
                    (make-list (- length 4) :initial-element 0))
            integer-vector)))

(defun compute-centroid-of-polygon-stamped (msg)
  "return geometry_msgs::PointStamped"
  (let ((output (instance geometry_msgs::PointStamped :init)))
    (send output :header (send msg :header))
    (let ((sum (float-vector 0 0 0))
          (point-num (length (send msg :polygon :points))))
      (dotimes (i point-num)
        (let ((p (elt (send msg :polygon :points) i)))
          (setq sum (v+ sum (float-vector (send p :x) (send p :y) (send p :z))))))
      (let ((centroid (scale (/ 1.0 point-num) sum)))
        (send output :point :x (elt centroid 0))
        (send output :point :y (elt centroid 1))
        (send output :point :z (elt centroid 2)))
      output)))

(defun pose-stamped-to-point-stamped (msg)
  (let ((point-stamped (instance geometry_msgs::PointStamped :init)))
    (send point-stamped :header (send msg :header))
    (send point-stamped :point :x (send msg :pose :position :x))
    (send point-stamped :point :y (send msg :pose :position :y))
    (send point-stamped :point :z (send msg :pose :position :z))
    point-stamped))

(defun integer-vector-to-rect-polygon-stamped (msg)
  (let ((x1 (elt (send msg :image_roi_info) 0))
        (y1 (elt (send msg :image_roi_info) 1))
        (x2 (elt (send msg :image_roi_info) 2))
        (y2 (elt (send msg :image_roi_info) 3)))
    (let ((ret (instance geometry_msgs::PolygonStamped :init)))
      (send ret :header :stamp (ros::time-now))
      (let ((p1 (instance geometry_msgs::Point32 :init))
            (p2 (instance geometry_msgs::Point32 :init)))
        (send p1 :x x1)
        (send p1 :y y1)
        (send p2 :x x2) 
        (send p2 :y y2)
        (send ret :polygon :points (list p1 p2))
        ret))))

(defun integer-vector-to-polygon-stamped (msg)
  (let ((params nil))
    (dotimes (i (/ (length (send msg :image_roi_info)) 2))
      (let ((x (elt (send msg :image_roi_info) (* i 2)))
            (y (elt (send msg :image_roi_info) (1+ (* i 2)))))
        (if (and (= x 0) (= y 0))
            (return-from nil nil)       ;break
          (setq params (append params (list (list x y)))))))
    (let ((ret (instance geometry_msgs::PolygonStamped :init)))
      (send ret :polygon :points (mapcar #'(lambda (p)
                                             (let ((point (instance geometry_msgs::Point32 :init)))
                                               (send point :x (car p))
                                               (send point :y (cadr p))
                                               point))
                                         params))
      (send ret :header :stamp (ros::time-now))
      ret)))

(defun coords-set-to-float-vector (coords-set length)
  (if (> (* 6 (length coords-set)) length)
      (progn
        (ros::ros-warn "Maximum number to convert is ~A" (/ length 6))))
  (let ((ret (instantiate float-vector length)))
    (dotimes (i (length coords-set))
      (if (<= (* (1+ i) 6) length)
          (fill-coords-float-vector (elt coords-set i) ret (* i 6))))
    ret))

(defun float-vector-to-coords-set (params)
  (let ((coords-set nil))
    (dotimes (i (/ (length params) 6))
      (let ((param0 (elt params (+ 0 (* i 6))))
            (param1 (elt params (+ 1 (* i 6))))
            (param2 (elt params (+ 2 (* i 6))))
            (param3 (elt params (+ 3 (* i 6))))
            (param4 (elt params (+ 4 (* i 6))))
            (param5 (elt params (+ 5 (* i 6)))))
        (if (and (= param0 0)
                 (= param1 0)
                 (= param2 0)
                 (= param3 0)
                 (= param4 0)
                 (= param5 0))
            (return-from nil nil)     ; all zero means end of coords set
          (setq coords-set (append coords-set (list (float-vector-to-coords 
                                                     (float-vector param0 param1 param2
                                                                   param3 param4 param5))))))
        ))
    coords-set))
  

(defun integer-vector-to-double-rect-polygon-stamped (msg)
  (let ((x1 (elt (send msg :image_roi_info) 0))
        (y1 (elt (send msg :image_roi_info) 1))
        (x2 (elt (send msg :image_roi_info) 2))
        (y2 (elt (send msg :image_roi_info) 3))
        (x3 (elt (send msg :image_roi_info) 4))
        (y3 (elt (send msg :image_roi_info) 5))
        (x4 (elt (send msg :image_roi_info) 6))
        (y4 (elt (send msg :image_roi_info) 7)))
    (let ((fore (instance geometry_msgs::PolygonStamped :init))
          (back (instance geometry_msgs::PolygonStamped :init))
          (now (ros::time-now)))
      (send fore :header :stamp now)
      (send back :header :stamp now)
      (let ((p1 (instance geometry_msgs::Point32 :init))
            (p2 (instance geometry_msgs::Point32 :init))
            (p3 (instance geometry_msgs::Point32 :init))
            (p4 (instance geometry_msgs::Point32 :init)))
        (send p1 :x x1)
        (send p1 :y y1)
        (send p2 :x x2)
        (send p2 :y y2)
        (send p3 :x x3)
        (send p3 :y y3)
        (send p4 :x x4)
        (send p4 :y y4)
        (send fore :polygon :points (list p1 p2))
        (send back :polygon :points (list p3 p4))
        (list fore back)))))

;; It's a circle actually
(defun torus-to-float-vector (coords radius length)
  (let ((ret (coords-to-float-vector coords length))) ;6 parameters are filled
    (setf (elt ret 6) radius)
    ret))

(defun float-vector-to-torus (params)
  (let ((coords (float-vector-to-coords params))
        (radius (elt params 6)))
    (list coords radius)))

(defun box-to-float-vector (coords dimensions length)
  "dimensions := geometry_msgs/Vector3"
  (let ((ret (coords-to-float-vector coords length)))
    (setf (elt ret 6) (elt dimensions 0))
    (setf (elt ret 7) (elt dimensions 1))
    (setf (elt ret 8) (elt dimensions 2))
    ret))

(defun float-vector-to-box (params)
  "returns (coords #f(width height depth))"
  (let ((coords (float-vector-to-coords params))
        (size (float-vector (elt params 6)
                            (elt params 7)
                            (elt params 8))))
    (list coords size)))

(defun cylinder-to-float-vector (coords radius height length)
  (let ((ret (coords-to-float-vector coords length)))
    (setf (elt ret 6) radius)
    (setf (elt ret 7) height)
    ret))

(defun float-vector-to-cylinder (params)
  (let ((coords (float-vector-to-coords params))
        (radius (elt params 6))
        (height (elt params 7)))
    (list coords radius height)))

(defun valve-params-to-float-vector             
  (valve-params valve-grasp-mode length)
  (let (ret)
    (setq ret (torus-to-float-vector (elt valve-params 0) (elt valve-params 1) length))
    (setf (elt ret 7) valve-grasp-mode)
    ret))

(defun float-vector-to-valve-params
  (params)
  (let ((ret (float-vector-to-torus params)))
    (append ret (list (elt params 7)))
    ))

(defun door-params-to-float-vector
  (door-params door-push/pull door-name door-reach-deg keep-grasp? length)
  (let (ret)
    (setq ret (box-to-float-vector (car door-params) (cadr door-params) length))
    (setf (elt ret 9) door-push/pull)
    (setf (elt ret 10) door-name)
    (setf (elt ret 11) door-reach-deg)
    (setf (elt ret 12) keep-grasp?)
    ret))

(defun float-vector-to-door-params
  (params)
  (let ((ret (float-vector-to-box params)))
    (append ret (list (elt params 9) (elt params 10) (elt params 11) (elt params 12)))
    ))

(defun reach-until-touch-params-to-float-vector
  (dir thre max-dist dist-step time-step rotation-axis length)
  (let (ret)
    (setq ret (position-to-float-vector dir length))
    (setf (elt ret 3) thre)
    (setf (elt ret 4) max-dist)
    (setf (elt ret 5) dist-step)
    (setf (elt ret 6) time-step)
    (setf (elt ret 7) (if rotation-axis 1 0))
    ret))

(defun float-vector-to-reach-until-touch-params
  (params)
  (list
   (float-vector-to-position params)
   (elt params 3) (elt params 4) (elt params 5) (elt params 6)
   (if (eps= (float (elt params 7)) (float 1)) t nil))
  )

;; message handler
(defclass narrowband-message-handler
  :super propertied-object
  :slots (deligate-map always-deligate-object always-deligate-method))

(defmethod narrowband-message-handler
  (:init ()
    (setq deligate-map nil)
    self)
  (:register-always-callback (obj method)
    (setq always-deligate-object obj)
    (setq always-deligate-method method))
  (:root-callback (msg)
    (if (and always-deligate-object always-deligate-method)
        (send always-deligate-object always-deligate-method msg))
    (let ((type (send msg :type)))
      (print (assoc type deligate-map))
      (if (assoc type deligate-map)
          (send (car (cdr (assoc type deligate-map)))
                (cdr (cdr (assoc type deligate-map)))
                msg)
        (ros::ros-warn "received unknown type ~A" type))))
  (:register-callback (type deligate-object deligate-method)
    (if (assoc type deligate-map)
        (error "you've already registered ~A" type))
    (setq deligate-map (append
                        (list (cons type
                                    (cons deligate-object
                                          deligate-method)))
                        deligate-map))
    )
  (:register-callbacks (&rest specs)
    (dolist (spec specs)
      (ros::ros-warn "registering ~A" spec)
      (send* self :register-callback spec)))
  )

(defun footstep-array->vector (footstep-array float-length integer-length)
  (let ((footstep-coords (mapcar #'(lambda (f)
                                     (ros::tf-pose->coords (send f :pose)))
                                 (send footstep-array :footsteps))))
    (let ((integer-vector-ret (instantiate integer-vector integer-length)))
      (dotimes (i (length (send footstep-array :footsteps)))
        (setf (elt integer-vector-ret i) (send (elt (send footstep-array :footsteps) i) :leg)))
      (list (coords-set-to-float-vector footstep-coords float-length)
            integer-vector-ret))))

(defun vector->footstep-array (float-footsteps int-footsteps)
  (let ((ret (instance jsk_footstep_msgs::FootstepArray :init)))
    (let ((coords-set (float-vector-to-coords-set float-footsteps)))
      (dotimes (i (length coords-set))
        (let ((footstep (instance jsk_footstep_msgs::Footstep :init)))
          (send footstep :pose (ros::coords->tf-pose (elt coords-set i)))
          (send footstep :leg (elt int-footsteps i))
          (send ret
                :footsteps (append (send ret :footsteps)
                                   (list footstep))))))
    ret))

;; class to synchronize foreground rect topic and
;; background rect topic
(defclass foreground-background-synchronizer
  :super exact-time-message-filter
  :slots (deligate callback))

(defmethod foreground-background-synchronizer
  (:init (topics deligate-object callback-method)
    (setq deligate deligate-object)
    (setq callback callback-method)
    (send-super :init topics)
    )
  (:callback (foreground background)
    (send deligate callback foreground background)
    ))

(defmacro push-back (el lst)
  `(if (null ,lst)
       (setf ,lst (list ,el))
     (nconc ,lst (list ,el))))

(defun keyshot-request
  ()
  (call-empty-service "keyshot/snapshot/request")
  )
