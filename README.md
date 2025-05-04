Controls the patch in my 3u rack through crow, primarily controlling params of txo as an enveloped oscillator and w/syn, which are played via ansible.

# todo
- [ ] more ways of controlling fm ratio
- [ ] test midi mapping
- [ ] improve separation of trackball and params
    - currently the "sensitivity" of the trackball is simply the quantum of the params, should separate this further. Questions: how to make turning param knob lock in to desired steps, even when trackball may set the value to something in between? Maybe an underlying hidden param that is controlled by both?
