OMC=omc -d=gendebugsymbols
TARGETS=au_incubator.fmu roomM370.fmu mh30_tank.fmu

all: $(TARGETS)
.PHONY:	all list-targets

clean:
	rm -f $(TARGETS)

roomM370.fmu: roomM370.mo
	$(OMC) doit.mos

au_incubator.fmu: au_incubator.mo
	$(OMC) buildIncubator.mos

mh30_tank.fmu: mh30_tank.mo
	$(OMC) build_mh30fmu.mos

list-targets:
	$(info $(TARGETS))
	@/bin/true 
