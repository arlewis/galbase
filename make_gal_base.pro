pro make_gal_base $
   , data_dir = data_dir

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; INITIALIZE
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  digit = ['0','1','2','3','4','5','6','7','8','9']

  data_dir = "gal_data/"

  empty = empty_gal_struct()

  leda_files = $
     ["leda_vlsr5000.fits" $
      ,"leda_atlas3d.fits" $
      ,"leda_califa.fits" $
      ,"leda_s4g.fits" $
      ,"leda_lga2mass.fits" $      
      ,"leda_sings.fits" $ 
     ]
  n_leda_files = n_elements(leda_files)

  lsun = 3.862d33
  pc = 3.0857000d18

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; BUILD THE BASIC DATABASE USING LEDA
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... reading LEDA files.", /info

  for jj = 0, n_leda_files-1 do begin

     infile = data_dir+leda_files[jj]
     leda = mrdfits(infile, 1, hdr)

     n_leda = n_elements(leda)
     this_data = replicate(empty, n_leda)

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; FILL IN LEDA INFORMATION
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

     this_data.name = strupcase(strcompress(leda.objname,/rem))
     this_data.pgc = leda.pgc
     this_data.pgcname = 'PGC'+strupcase(strcompress(str(leda.pgc),/rem))

     has_modz = where(finite(leda.modz), ct)
     if ct gt 0 then begin
        this_data[has_modz].leda_vdist_mpc = 10.^(leda[has_modz].modz/5.+1.)/1d6
        this_data[has_modz].e_leda_vdist = !values.f_nan
        this_data[has_modz].dist_mpc = this_data[has_modz].leda_vdist_mpc
        this_data[has_modz].ref_dist = 'LEDA_VFLOW'
     endif

     has_mod0 = where(finite(leda.mod0), ct)     
     if ct gt 0 then begin        
        this_data[has_mod0].leda_dist_mpc = 10.^(leda[has_mod0].mod0/5.+1.)/1d6
        this_data[has_mod0].e_leda_dist = 10.^(leda[has_mod0].mod0/5.+1.)/1d6
        this_data[has_mod0].dist_mpc = this_data[has_mod0].leda_dist_mpc
        this_data[has_mod0].ref_dist = 'LEDA'
     endif

;    RECESSIONAL VELOCITY
     this_data.vhel_kms = leda.v
     this_data.e_vhel_kms = leda.e_v
     
     this_data.vrad_kms = leda.vrad
     this_data.e_vrad_kms = leda.e_vrad
     
     this_data.vvir_kms = leda.vvir
     
;    POSITION
     this_data.ra_deg = leda.al2000*15.0
     this_data.dec_deg = leda.de2000
     
;    ORIENTATION
     this_data.posang_deg = leda.pa
     this_data.incl_deg = leda.incl
     
     this_data.log_raxis = leda.logr25
     this_data.e_log_raxis = leda.e_logr25
     
;    MORPHOLOGY
     this_data.t = leda.t
     this_data.e_t = leda.e_t
     
     this_data.morph = leda.type
     this_data.bar = strupcase(leda.bar) eq 'B'
     this_data.ring = strupcase(leda.bar) eq 'R'
     this_data.multiple = strupcase(leda.bar) eq 'M'

;    SIZE  
     this_data.r25_deg = 10.^(leda.logd25)/10./60./2.
     this_data.e_r25_deg = (10.^(leda.e_logd25)-1.)*this_data.r25_deg
     
;    ROTATION CURVES
     this_data.vmaxg_kms = leda.vmaxg
     this_data.e_vmaxg_kms = leda.e_vmaxg

     this_data.vrot_kms = leda.vrot
     this_data.e_vrot_kms = leda.e_vrot

;    LUMINOSITIES/FLUXES

;    ... HI
     this_data.hi_msun = $
        10.^((leda.m21 - 17.4)/(-1.*2.5))*(2.36d5*this_data.dist_mpc^2)

;    ... IR
     this_data.lfir_lsun = 10.^((leda.mfir -14.75)/(-2.5))*1.26d-14*1d3* $
                           (4.0*!pi*(this_data.dist_mpc*1d6*pc)^2)/lsun
     
;    ... OPTICAL
     this_data.btc_mag = leda.btc
     this_data.ubtc_mag = leda.ubtc
     this_data.bvtc_mag = leda.bvtc
     this_data.itc_mag = leda.itc

;    ... WORK OUT ALIASES THAT LEDA KNOWS
     for i = 0L, n_leda-1 do begin
        if strcompress(leda[i].hl_names,/rem) eq '' then continue
        names = strsplit(strcompress(leda[i].hl_names,/rem), ',', /extract)
        for j = 0, n_elements(names)-1 do begin
           if this_data[i].alias eq '' then $
              this_data[i].alias = names[j] $
           else $
              this_data[i].alias += ';'+names[j]
        endfor
     endfor
     
;    ... STRIP LEADING ZEROS FROM NGC, UGC, PGC, AND IC ENTRIES

     for i = 0L, n_elements(this_data)-1 do begin

        this_names = strsplit(this_data[i].alias, ';', /extract)
        n_names = n_elements(this_names)

        for kk = 0, n_names-1 do begin

           this_name = this_names[kk]
        
           if (strpos(this_name, "NGC") eq 0) or $
              (strpos(this_name, "UGCA") eq 0) or $
              (strpos(this_name, "UGC") eq 0) or $         
              (strpos(this_name, "IC") eq 0) or $
              (strpos(this_name, "PGC") eq 0) or $
              (strpos(this_name, "MESSIER") eq 0) $
           then begin
              this_alias = ""
              leading_digit = 1B
              was_zero = 0B

              for zz = 0, strlen(this_name)-1 do begin
                 token = strmid(this_name,zz,1)
                 if total(token eq digit) eq 1 then begin
                    if leading_digit and token eq '0' then begin
                       was_zero = 1B
                       continue
                    endif
                    leading_digit = 0B
                    this_alias += token
                 endif else begin
                    this_alias += token
                 endelse
              endfor

              if was_zero and $
                 (total(this_names eq this_alias) eq 0) then begin
                 if this_data[i].alias eq '' then $
                    this_data[i].alias = this_alias $
                 else $
                    this_data[i].alias += ';'+this_alias           
              endif
           endif
           
        endfor

;       HANDLE THE MESSIER <-> M

        this_names = strsplit(this_data[i].alias, ';', /extract)
        n_names = n_elements(this_names)

        for kk = 0, n_names-1 do begin
           
           this_name = this_names[kk]
           
           if (strpos(this_name, "MESSIER") eq 0) then begin
              this_alias = str_replace(this_name,'MESSIER','M')
              if total(this_names eq this_alias) eq 0 then begin
                 if this_data[i].alias eq '' then $
                    this_data[i].alias = this_alias $
                 else $
                    this_data[i].alias += ';'+this_alias
              endif
           endif

        endfor
        
     endfor

;    COMPILE DATA STRUCTURE

     if n_elements(data) gt 0 then begin
        data = [data, this_data]
     endif else begin
        data = this_data
     endelse

  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; REMOVE DUPLICATIONS BASED ON PGC NUMBER
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... removing duplicates", /info
  uniq_ind = uniq(data.pgc, sort(data.pgc))
  data = data[uniq_ind]

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; FILL IN USER SUPPLIED ALIASES
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... adding user supplied aliases", /info

  readcol, data_dir+"alias.txt", format="A,A" $
           , comment="#", name, alias, /silent
  name = strupcase(strcompress(name,/rem))
  alias = strupcase(strcompress(alias, /rem))

  n_alias = n_elements(alias)
  n_data = n_elements(data)

  for i = 0L, n_alias-1 do begin
     ind = where(data.name eq name[i], match_ct)
     if match_ct eq 0 then begin
        for j = 0L, n_data-1 do begin
           names = strsplit(data[j].alias, ';', /extract)
           if total(strupcase(names) eq name[i]) eq 1 then begin
              ind = j
              match_ct = 1
              break
           endif
        endfor
        if match_ct eq 0 then begin
           print, "USER SUPPLIED ALIAS: No match for "+name[i]
           continue
        endif
     endif
     
     names = strsplit(data[ind].alias, ';', /extract)
     if total(strupcase(alias[i]) eq strupcase(names)) eq 0 then begin
        if data[ind].alias eq '' then $
           data[ind].alias = alias[i] $
        else $
           data[ind].alias += ';'+alias[i]
     endif

  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MAKE THE PAIRED ALIAS/NAME VECTOR
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  n_data = n_elements(data)-1
  n_names = 0
  for i = 0L, n_data-1 do begin
     n_names += 1
     aliases = strsplit(data[i].alias, ';', /extract)     
     n_names += n_elements(aliases)
  endfor

  alias_vec = strarr(n_names)
  name_vec = strarr(n_names)
  counter = 0L
  for i = 0L, n_data-1 do begin
     alias_vec[counter] = data[i].name
     name_vec[counter] = data[i].name
     counter += 1
     
     if data[i].alias eq '' then continue
     aliases = strsplit(data[i].alias, ';', /extract)     
     n_alias = n_elements(aliases)

     alias_vec[counter:(counter+n_alias-1)] = aliases
     name_vec[counter:(counter+n_alias-1)] = replicate(data[i].name, n_alias)
     counter += n_alias
  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MATCH TO NED
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... matching to NED information.", /info

; Read our NED query data. All kept in one file.

  nedfile = data_dir+'ned_data.txt'
  readcol $
     , nedfile, commen='#', delim='|' $
     , format = 'A,F,F,F,F,F,F,F,F,F,F,F' $
     , ned_name, ned_ra, ned_dec, ned_distmod, e_ned_distmod $
     , ned_d, e_ned_d, ned_mind, ned_maxd, ned_vhel, ned_vhel_err $
     , ned_av

  ned_name = strupcase(strcompress(ned_name,/rem))
  n_ned = n_elements(ned_name)

  pgc_name_vec = "PGC"+str(data.pgc)

  for ii = 0, n_ned-1 do begin

     counter, ii, n_ned-1, "Matching NED line "
     ind = where(pgc_name_vec eq ned_name[ii], match_ct)

     if match_ct eq 2 then $
        ind = ind[0]
     if match_ct eq 0 then continue
     if match_ct gt 2 then begin
        message, "Something seems wrong with the alias lookup. Stopping for debugging.", /info
        stop
     endif

     data[ind].av_sf11 = ned_av[ii]

     if finite(ned_d[ii]) then begin
        data[ind].ned_dist_mpc = ned_d[ii]
        data[ind].e_ned_dist = e_ned_d[ii]
     endif
     
  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MATCH TO S4G TABLE
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "...cross-matching with S4G.", /info

  s4g = read_ipac_table('gal_data/s4g_ipac_table.txt')
  n_s4g = n_elements(s4g.object)

  s4g_matches = 0
  for ii = 0, n_s4g-1 do begin

     ind = where(s4g.object[ii] eq alias_vec, ct)
     if ct eq 0 then continue

     this_name = name_vec[ind[0]]
     ind = where(data.name eq this_name, ct)
     if ct eq 0 then continue

     data[ind].s4g_pa = $
        s4g.pa1_25p5[ii]+(180.)*(s4g.pa1_25p5[ii] lt 0.)

     data[ind].s4g_ellip = s4g.ellip1_25p5[ii]
     q = 0.22
     s4g_rat = (1.0-data[ind].s4g_ellip)
     data[ind].s4g_incl = acos(sqrt((s4g_rat^2 - q^2)/(1.-q^2)))/!dtor

     ;s4g_r0 = (data[ind].t gt 7)*0.38 + $
     ;         (data[ind].t le 7 and data[ind].t gt -5.)* $
     ;         (data[ind].t*0.053+0.43)              
     ;s4g_incl = asin(sqrt((1.-10.^(-2.*s4g_logr25))/(1.-10.^(-2.*s4g_r0))))
     ;data[ind].s4g_incl = s4g_incl     

     data[ind].s4g_i3p6_mag = s4g.mag1[ii]
     data[ind].s4g_i4p5_mag = s4g.mag2[ii]
     data[ind].s4g_mstar = s4g.mstar[ii]
     data[ind].s4g_dist_mpc = s4g.dmean[ii]
     data[ind].s4g_semimaj = s4g.sma1_25p5[ii]

     s4g_matches += 1

  endfor
  
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MATCH TO COSMIC FLOWS DATABASE
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... reading in CosmicFlows 3 distances.", /info

  readcol, 'gal_data/EDD_CF3_2017Sep28.txt', delim='|', comment='#' $
           , cf3_pgc, cf3_dist, cf3_ndist, cf3_dm, cf3_edm, cf3_dmgrp, cf3_edgmgrp $
           , format='L,F,L,F,F,F,F', /nan
  cf3_group_dist = 10.^(cf3_dmgrp/5.+1.)/1d6

  n_data = n_elements(data)
  for ii = 0, n_data-1 do begin
     ind = where(cf3_pgc eq data[ii].pgc, ct)
     if ct eq 0 then continue
     if ct gt 1 then stop

     data[ii].cf_dist_mpc = (cf3_dist[ind])[0]
     data[ii].cf_grp_dist = (cf3_group_dist[ind])[0]
     if abs(cf3_dist[ind] - data[ii].cf_dist_mpc) gt 1d2 then stop
     err = (cf3_dist[ind]*(10.^(cf3_edm[ind]/5.)-1.d))[0]
     data[ii].e_cf_dist = err

     old_d = data[ind].dist_mpc
     
     data[ii].dist_mpc = data[ii].cf_dist_mpc
     data[ii].e_dist = data[ii].e_cf_dist
     data[ii].ref_dist = 'CF3'

     data[ii].lfir_lsun = data[ii].lfir_lsun*(data[ii].dist_mpc/old_d)^2
     data[ii].hi_msun = data[ii].hi_msun*(data[ii].dist_mpc/old_d)^2

  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MATCH TO EXTRAGALACTIC DISTANCE DATABASE
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... reading in EDD distances.", /info

  readcol, 'gal_data/EDD_EDD_2017Sep27.txt', comment='#', delim='|' $
           , edd_pgc, edd_dist, edd_edist, edd_source $
           , format='L,X,F,F,X,X,X,X,X,X,X,X,X,X,L', /nan

  n_data = n_elements(data)
  for ii = 0, n_data-1 do begin
     ind = where(edd_pgc eq data[ii].pgc, ct)
     if ct eq 0 then continue
     if ct gt 1 then stop

     data[ii].edd_dist_mpc = (edd_dist[ind])[0]
     if abs(edd_dist[ind] - data[ii].edd_dist_mpc) gt 1d2 then stop
     err = (edd_edist[ind])[0]
     data[ii].e_edd_dist = err
     data[ii].edd_code = (edd_source[ind])[0]

     old_d = data[ind].dist_mpc
     
     data[ii].dist_mpc = data[ii].edd_dist_mpc
     data[ii].e_dist = data[ii].e_edd_dist
     data[ii].ref_dist = 'EDD'

     data[ii].lfir_lsun = data[ii].lfir_lsun*(data[ii].dist_mpc/old_d)^2
     data[ii].hi_msun = data[ii].hi_msun*(data[ii].dist_mpc/old_d)^2

  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; NOW READ IN ANY USER-SUPPLIED OVERRIDE FILES
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... applying user overrides.", /info

  override_files = file_search("gal_data/override_*.txt", count=ct)

; BUILD THE INFRASTRUCTURE TO LOOK UP TAG NAMES
  data_tags = tag_names(data)

; LOOP THROUGH THE OVERRIDE FILES
  for j = 0L, ct-1 do begin

     print, "Applying override file : ", override_files[j]

;    Convention is NAME, FIELD, VALUE, REFERENCE
;    ... need to generalize to allow strings.
     readcol, override_files[j], comment="#" $
              , format="A,A,A" $
              , galaxy, field, value
     galaxy = strupcase(strcompress(galaxy, /rem))
     field = strupcase(strcompress(field, /rem))
     
     for k = 0L, n_elements(galaxy)-1 do begin

        tag_ind = where(data_tags eq field[k], tag_ct)
        if tag_ct eq 0 then begin
           message, "OVERRIDE FILE: "+override_files[j]+" No match for field "+field[k], /info
           continue
        endif
        
        name_ind = where(alias_vec eq galaxy[k], name_ct)
        if name_ct eq 0 then begin
           message, "No match for name "+galaxy[k], /info
           continue
        endif
        data_ind = where(data.name eq (name_vec[name_ind])[0])

        if strupcase(field[k] eq 'DIST_MPC') then begin          
           old_d = data[data_ind].dist_mpc    
        endif

        data[data_ind].(tag_ind) = value[k]

        if strupcase(field[k] eq 'DIST_MPC') then begin          
           data[data_ind].lfir_lsun = data[data_ind].lfir_lsun*(data[data_ind].dist_mpc/old_d)^2
           data[data_ind].hi_msun = data[data_ind].hi_msun*(data[data_ind].dist_mpc/old_d)^2
        endif

     endfor
     
  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; TAG SURVEY MEMBERSHIP
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  message, "... tagging survey membership.", /info

  survey_files = file_search("gal_data/survey_*.txt", count=ct)

; LOOP THROUGH THE SURVEY FILES
  for j = 0L, ct-1 do begin

     survey_name = strmid(survey_files[j] $
                          , 0, strlen(survey_files[j])-4)
     survey_name = strupcase(survey_name)
     survey_name = $
        (strmid(survey_name, strpos(survey_name,'SURVEY_')+strlen('SURVEY_')))

     print, "Applying survey file : ", survey_files[j], " as survey ", survey_name

     readcol, survey_files[j], comment="#" $
              , format="A" $
              , galaxy
     galaxy = strupcase(strcompress(galaxy, /rem))
     
     for k = 0L, n_elements(galaxy)-1 do begin
        
        name_ind = where(alias_vec eq galaxy[k], name_ct)
        if name_ct eq 0 then begin
           message, "SURVEY "+survey_files[j]+" No match for name "+galaxy[k], /info
           continue
        endif
        data_ind = where(data.name eq (name_vec[name_ind])[0])
        tags = data[data_ind].tags
        tags += ';'+survey_name+';'
        data[data_ind].tags = tags

     endfor
     
  endfor

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; WRITE TO DISK
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
  
  outfile = "gal_data/gal_base.fits"
  mwrfits, data, outfile, hdr, /create

  openw, unit, "gal_data/gal_base_alias.txt", /get_lun
  printf, unit, '# Column 1: alias'
  printf, unit, '# Column 2: name in database'
  for ii = 0, n_elements(name_vec)-1 do begin
     printf, unit, alias_vec[ii]+" "+name_vec[ii]
  endfor
  close, unit

end
