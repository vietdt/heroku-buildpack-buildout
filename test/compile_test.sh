#!/bin/sh

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

afterSetUp()
{
  # set test APP_DIR inside tmp folder
  APP_DIR="${OUTPUT_DIR}/app"

  if [ ! -d $BUILD_DIR/.heroku ]; then
    mkdir ${BUILD_DIR}/.heroku
    # use system virtualenv to create python inside BUILD_DIR/.heroku
    # or just create a symlink if tests run on heroku
    virtualenv ${BUILD_DIR}/.heroku/python || ln -s ${BUILDPACK_HOME}/.heroku/python $BUILD_DIR/.heroku/python
  fi

  # copy default bootstrap.py & buildout.cfg to BUILD_DIR
  cp ${BUILDPACK_HOME}/bootstrap.py ${BUILD_DIR}/bootstrap.py
  cp ${BUILDPACK_HOME}/buildout.cfg ${BUILD_DIR}/buildout.cfg
}

testPythonBuildpackFail()
{
  # make sure the test failed if python not found in $BUILD_DIR/.heroku/
  rm -rf ${BUILD_DIR}/.heroku/python

  capture ${BUILDPACK_HOME}/bin/compile ${BUILD_DIR} ${CACHE_DIR} ${ENV_DIR} ${APP_DIR}
  assertEquals 1 ${rtrn}
  assertCaptured "-----> This buildpack depends on heroku-buildpack-python."
}

testCompile()
{
  capture ${BUILDPACK_HOME}/bin/compile ${BUILD_DIR} ${CACHE_DIR} ${ENV_DIR} ${APP_DIR}
  assertEquals 0 ${rtrn}
  assertNotCaptured "-----> Use PYPICloud"
  assertCaptured "Cache empty, start from scratch"
  assertCaptured "Use default buildout.cfg"
  assertCaptured "Use default buildout verbosity"
  assertCaptured "Use default bootstrap verbosity"
  assertCaptured "Use default pip version: ${VERSION_PIP}"
  assertCaptured "Use default setuptools version: 20.4"

  assertTrue "$APP_DIR/.heroku/ should be present in runtime." "[ -d $APP_DIR/.heroku ]"
  assertTrue "python symlink should be present." "[ -L $APP_DIR/.heroku/python ]"
  assertTrue "eggs should be present in build dir." "[ -d $BUILD_DIR/eggs ]"
  assertTrue "eggs should be present in cache dir." "[ -d $CACHE_DIR/eggs ]"
  assertTrue "Sphinx should be present in bin." "[ -f $BUILD_DIR/bin/sphinx-build ]"

  assertCaptured "Done"

  # Run again to ensure cache is used.
  rm -rf ${BUILD_DIR}/*
  rm -f $APP_DIR/.heroku/python
  resetCapture
  afterSetUp
  compileWithEnvVars
}

compileWithEnvVars()
{
  #-* test compile with env vars set *-#
  # set credentials for third party PyPI installations
  echo "foo" > $ENV_DIR/PYPICLOUD_USERNAME
  echo "bar" > $ENV_DIR/PYPICLOUD_PASSWORD
  # set BUILDOUT_CFG file
  echo "buildout.cfg" > $ENV_DIR/BUILDOUT_CFG
  # set Buildout verbosity
  echo "-v" > $ENV_DIR/BUILDOUT_VERBOSITY
  # set Bootstrap verbosity
  echo "-v" > $ENV_DIR/BOOTSTRAP_VERBOSITY
  # set pip version
  echo "8.1.1" > $ENV_DIR/VERSION_PIP
  # set setuptools version
  echo "20.4" > $ENV_DIR/VERSION_SETUPTOOLS

  capture ${BUILDPACK_HOME}/bin/compile ${BUILD_DIR} ${CACHE_DIR} ${ENV_DIR} ${APP_DIR}
  assertEquals 0 ${rtrn}
  assertCaptured "Get buildout results from the previous build" # cache worked
  assertCaptured "-----> Use PYPICloud"
  assertCaptured "Found ${BUILDOUT_CFG}"
  assertCaptured "Use buildout verbosity: ${BUILDOUT_VERBOSITY}"
  assertCaptured "Use pip version: ${VERSION_PIP}"
  assertCaptured "Use setuptools version: ${VERSION_SETUPTOOLS}"
  assertCaptured "Done"
}

testBuildoutVerbosityFail()
{
    # make sure the test failed if BUILDOUT_VERBOSITY set to something else
    # other than -v, -vv, -vvv, etc.

    # set Buildout verbosity
    echo "foo " > $ENV_DIR/BUILDOUT_VERBOSITY

    capture ${BUILDPACK_HOME}/bin/compile ${BUILD_DIR} ${CACHE_DIR} ${ENV_DIR} ${APP_DIR}
    assertEquals 1 ${rtrn}
    assertCaptured "You need to set BUILDOUT_VERBOSITY to -v, -vv, -vvv, etc."
}

testBootstrapVerbosityFail()
{
    # make sure the test failed if BOOTSTRAP_VERBOSITY set to something else
    # other than -v, -vv, -vvv, etc.

    # set Bootstrap verbosity
    echo "bar" > $ENV_DIR/BOOTSTRAP_VERBOSITY

    capture ${BUILDPACK_HOME}/bin/compile ${BUILD_DIR} ${CACHE_DIR} ${ENV_DIR} ${APP_DIR}
    assertEquals 1 ${rtrn}
    assertCaptured "You need to set BOOTSTRAP_VERBOSITY to -v, -vv, -vvv, etc."
}
