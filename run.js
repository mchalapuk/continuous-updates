
const yaml = require('js-yaml');
const git = require('simple-git');
const mkdir = require('mkdirp');
const rimraf = require('rimraf');
const fs = require('fs');

const check = require('offensive').default;
require('offensive/assertions/allElementsThat/register');
require('offensive/assertions/fieldThat/register');
require('offensive/assertions/aString/register');
require('offensive/assertions/allElementsThat/register');

const WORKSPACE = `${__dirname}/workspace/`;

cwd(__dirname);
const config = readConfigFile();

runAll(config.pkgs, 0);

function log(msg) {
  process.stdout.write(msg);
}

function cwd(dir) {
  console.info(`cwd: ${dir}`);
  process.cwd(dir);
}

function readConfigFile() {
  const config = yaml.safeLoad(fs.readFileSync('./config.yml', 'utf-8'));

  log('Validating config.yml');
  check(config, 'config')
    .has.fieldThat('pkgs', field => field
      .contains.allElementsThat(elem => elem
        .has.fieldThat('name', name => name.is.aString)
        .and.fieldThat('repoUrl', repoUrl => repoUrl.is.aString)
        .and.fieldThat('pwdVar', pwdVar => pwdVar.is.aString)
        .and.fieldThat('testTask', testTask => testTask.is.aString)
      )
    )
    ()
  ;
  log(' [success]\n');
  return config;
}

function runAll(pkgs, index) {
  if (index === pkgs.length) {
    return;
  }
  run(pkgs[index])
    .then(
      () => runAll(pkgs, index + 1),
      err => {
        console.error(err);
        system.exit(1);
      },
    )
  ;
}

async function run(pkg) {
  log(`--- ${pkg.name} ---\n`);
  cwd(WORKSPACE);

  const folder = `${WORKSPACE}${pkg.name}`;
  log(`Removing folder: ${folder}`);
  rimraf.sync(folder);
  log(' [success]\n');

  const repo = git().silent(true);

  log(`Cloning ${pkg.repoUrl}`);
  await repo.clone(pkg.repoUrl, folder);
  log(' [success]\n');

  cwd(folder);
}

